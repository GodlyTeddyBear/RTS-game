--!strict

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

type TSetupAimRequest = Types.TSetupAimRequest
type TIKAimRigConfig = Types.TIKAimRigConfig

local Motor6DAimRuntime = {}

local function _ResolveByPath(root: Instance, instancePath: string): Instance?
	local current: Instance? = root
	for segment in string.gmatch(instancePath, "[^%.]+") do
		current = current and current:FindFirstChild(segment) or nil
		if current == nil then
			return nil
		end
	end
	return current
end

local function _ResolveMotor(model: Model, rigConfig: TIKAimRigConfig): Motor6D?
	if type(rigConfig.MotorPath) == "string" and rigConfig.MotorPath ~= "" then
		local resolved = _ResolveByPath(model, rigConfig.MotorPath)
		return if resolved ~= nil and resolved:IsA("Motor6D") then resolved else nil
	end
	return model:FindFirstChildWhichIsA("Motor6D", true)
end

local function _ResolvePart(model: Model, rigConfig: TIKAimRigConfig, motor: Motor6D): BasePart?
	if type(rigConfig.PartPath) == "string" and rigConfig.PartPath ~= "" then
		local resolved = _ResolveByPath(model, rigConfig.PartPath)
		if resolved ~= nil and resolved:IsA("BasePart") then
			return resolved
		end
	end
	return if motor.Part1 ~= nil then motor.Part1 else motor.Part0
end

function Motor6DAimRuntime.Start(request: TSetupAimRequest): (() -> ())?
	local motor = _ResolveMotor(request.Model, request.RigConfig)
	if motor == nil then
		warn("Motor6DAimRuntime: failed to resolve Motor6D for model", request.Model:GetFullName())
		return nil
	end

	local part = _ResolvePart(request.Model, request.RigConfig, motor)
	if part == nil then
		warn("Motor6DAimRuntime: failed to resolve aim part for model", request.Model:GetFullName())
		return nil
	end

	local originalTransform = motor.Transform
	local yawLimit = math.rad(request.RigConfig.YawLimit or 70)
	local pitchLimit = math.rad(request.RigConfig.PitchLimit or 35)
	local weight = math.clamp(request.RigConfig.Weight or 1, 0, 1)
	local connection

	connection = RunService.PreSimulation:Connect(function()
		local target = request.GetTargetWorldPosition()
		if target == nil then
			motor.Transform = originalTransform
			return
		end

		local worldDelta = target - part.Position
		if worldDelta.Magnitude <= 0.001 then
			return
		end

		local localDirection = part.CFrame:VectorToObjectSpace(worldDelta.Unit)
		local yaw = math.clamp(math.atan2(-localDirection.X, -localDirection.Z), -yawLimit, yawLimit)
		local pitch = math.clamp(math.asin(localDirection.Y), -pitchLimit, pitchLimit)
		motor.Transform = originalTransform:Lerp(CFrame.Angles(pitch, yaw, 0), weight)
	end)

	return function()
		if connection ~= nil then
			connection:Disconnect()
			connection = nil
		end
		motor.Transform = originalTransform
	end
end

return Motor6DAimRuntime
