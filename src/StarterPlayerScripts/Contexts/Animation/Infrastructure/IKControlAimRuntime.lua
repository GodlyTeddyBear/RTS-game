--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

local DEFAULT_SMOOTH_TIME = 0.15
local DEFAULT_WEIGHT = 1

type TSetupAimRequest = Types.TSetupAimRequest
type TIKAimRigConfig = Types.TIKAimRigConfig

type TControlHost = Humanoid | AnimationController

type TAimState = {
	Connection: RBXScriptConnection?,
	ModelConnection: RBXScriptConnection?,
	IKControl: IKControl,
	TargetPart: Part,
	GetTargetWorldPosition: () -> Vector3?,
	RigConfig: TIKAimRigConfig,
}

local IKControlAimRuntime = {}

local _BuildAimState: (request: TSetupAimRequest) -> TAimState?
local _ResolveControllerHost: (model: Model) -> TControlHost?
local _ResolveChainRoot: (model: Model, rigConfig: TIKAimRigConfig) -> Instance?
local _ResolveEndEffector: (model: Model, rigConfig: TIKAimRigConfig) -> Instance?
local _ResolveByPath: (root: Instance, instancePath: string) -> Instance?
local _CreateTargetPart: (model: Model) -> Part
local _Step: (state: TAimState) -> ()
local _Cleanup: (state: TAimState) -> ()

function IKControlAimRuntime.Start(request: TSetupAimRequest): (() -> ())?
	local state = _BuildAimState(request)
	if state == nil then
		return nil
	end

	state.Connection = RunService.PreSimulation:Connect(function()
		_Step(state)
	end)

	state.ModelConnection = request.Model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			_Cleanup(state)
		end
	end)

	return function()
		_Cleanup(state)
	end
end

function _BuildAimState(request: TSetupAimRequest): TAimState?
	local controllerHost = _ResolveControllerHost(request.Model)
	if controllerHost == nil then
		warn("IKControlAimRuntime: failed to resolve Humanoid or AnimationController for model", request.Model:GetFullName())
		return nil
	end

	local chainRoot = _ResolveChainRoot(request.Model, request.RigConfig)
	if chainRoot == nil then
		warn("IKControlAimRuntime: failed to resolve chain root for model", request.Model:GetFullName())
		return nil
	end

	local endEffector = _ResolveEndEffector(request.Model, request.RigConfig)
	if endEffector == nil then
		warn("IKControlAimRuntime: failed to resolve end effector for model", request.Model:GetFullName())
		return nil
	end

	local targetPart = _CreateTargetPart(request.Model)
	targetPart.CFrame = request.Model:GetPivot()

	local ikControl = Instance.new("IKControl")
	ikControl.Name = "RuntimeAimIKControl"
	ikControl.Type = Enum.IKControlType.LookAt
	ikControl.ChainRoot = chainRoot
	ikControl.EndEffector = endEffector
	ikControl.Target = targetPart
	ikControl.SmoothTime = math.max(request.RigConfig.SmoothTime or DEFAULT_SMOOTH_TIME, 0)
	ikControl.Weight = math.clamp(request.RigConfig.Weight or DEFAULT_WEIGHT, 0, 1)
	ikControl.Priority = request.RigConfig.Priority or 0
	ikControl.Enabled = false
	ikControl.Parent = controllerHost

	if ikControl:GetChainCount() <= 0 then
		ikControl:Destroy()
		targetPart:Destroy()
		warn("IKControlAimRuntime: resolved IK chain is empty for model", request.Model:GetFullName())
		return nil
	end

	return {
		Connection = nil,
		ModelConnection = nil,
		IKControl = ikControl,
		TargetPart = targetPart,
		GetTargetWorldPosition = request.GetTargetWorldPosition,
		RigConfig = request.RigConfig,
	}
end

function _ResolveControllerHost(model: Model): TControlHost?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		return humanoid
	end

	local animationController = model:FindFirstChildOfClass("AnimationController")
	if animationController ~= nil and animationController:FindFirstChildOfClass("Animator") ~= nil then
		return animationController
	end

	return nil
end

function _ResolveChainRoot(model: Model, rigConfig: TIKAimRigConfig): Instance?
	local chainRootPath = rigConfig.ChainRootPath
	if type(chainRootPath) ~= "string" or chainRootPath == "" then
		return nil
	end

	local resolved = _ResolveByPath(model, chainRootPath)
	if resolved ~= nil and (resolved:IsA("BasePart") or resolved:IsA("Bone")) then
		return resolved
	end

	return nil
end

function _ResolveEndEffector(model: Model, rigConfig: TIKAimRigConfig): Instance?
	local endEffectorPath = rigConfig.EndEffectorPath
	if type(endEffectorPath) == "string" and endEffectorPath ~= "" then
		local resolved = _ResolveByPath(model, endEffectorPath)
		if resolved ~= nil and (resolved:IsA("Attachment") or resolved:IsA("Bone") or resolved:IsA("BasePart")) then
			return resolved
		end
	end

	return nil
end

function _ResolveByPath(root: Instance, instancePath: string): Instance?
	local current: Instance? = root
	for segment in string.gmatch(instancePath, "[^%.]+") do
		current = current and current:FindFirstChild(segment) or nil
		if current == nil then
			return nil
		end
	end

	return current
end

function _CreateTargetPart(model: Model): Part
	local targetPart = Instance.new("Part")
	targetPart.Name = model.Name .. "_AimTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.CastShadow = false
	targetPart.Locked = true
	targetPart.Massless = true
	targetPart.Size = Vector3.new(0.2, 0.2, 0.2)
	targetPart.Transparency = 1
	targetPart.Parent = Workspace
	return targetPart
end

function _Step(state: TAimState)
	local ikControl = state.IKControl
	if ikControl.Parent == nil then
		_Cleanup(state)
		return
	end

	local targetWorldPosition = state.GetTargetWorldPosition()
	if targetWorldPosition == nil then
		if state.RigConfig.ReturnToNeutralWhenNoTarget == false then
			return
		end

		ikControl.Enabled = false
		return
	end

	state.TargetPart.CFrame = CFrame.new(targetWorldPosition)
	ikControl.Enabled = true
end

function _Cleanup(state: TAimState)
	if state.Connection ~= nil then
		state.Connection:Disconnect()
		state.Connection = nil
	end

	if state.ModelConnection ~= nil then
		state.ModelConnection:Disconnect()
		state.ModelConnection = nil
	end

	if state.IKControl.Parent ~= nil then
		state.IKControl:Destroy()
	end

	if state.TargetPart.Parent ~= nil then
		state.TargetPart:Destroy()
	end
end

return IKControlAimRuntime
