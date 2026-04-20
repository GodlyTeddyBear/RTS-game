--!strict

local RunService = game:GetService("RunService")

local LEAN_THRESHOLD = 2
local LEAN_ANGLE = 10
local LERP_SPEED = 0.2

local LeanSystem = {}

function LeanSystem.start(model: Model): () -> ()
	local hrp = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local torso = model:FindFirstChild("Torso") :: BasePart?
	if not hrp or not torso then
		return function() end
	end

	local rootJoint = hrp:FindFirstChild("RootJoint") :: Motor6D?
	local leftHip = torso:FindFirstChild("Left Hip") :: Motor6D?
	local rightHip = torso:FindFirstChild("Right Hip") :: Motor6D?
	if not rootJoint or not leftHip or not rightHip then
		return function() end
	end

	local rootC0 = rootJoint.C0
	local leftC0 = leftHip.C0
	local rightC0 = rightHip.C0
	local v1, v2 = 0, 0

	local conn = RunService.RenderStepped:Connect(function()
		local flat = hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		if flat.Magnitude > LEAN_THRESHOLD then
			local dir = flat.Unit
			v1 = hrp.CFrame.RightVector:Dot(dir)
			v2 = hrp.CFrame.LookVector:Dot(dir)
		else
			v1, v2 = 0, 0
		end

		rootJoint.C0 = rootJoint.C0:Lerp(
			rootC0 * CFrame.Angles(math.rad(v2 * LEAN_ANGLE), math.rad(-v1 * LEAN_ANGLE), 0),
			LERP_SPEED
		)
		leftHip.C0 = leftHip.C0:Lerp(
			leftC0 * CFrame.Angles(math.rad(v1 * LEAN_ANGLE), 0, 0),
			LERP_SPEED
		)
		rightHip.C0 = rightHip.C0:Lerp(
			rightC0 * CFrame.Angles(math.rad(-v1 * LEAN_ANGLE), 0, 0),
			LERP_SPEED
		)
	end)

	return function()
		conn:Disconnect()
		rootJoint.C0 = rootC0
		leftHip.C0 = leftC0
		rightHip.C0 = rightC0
	end
end

return LeanSystem
