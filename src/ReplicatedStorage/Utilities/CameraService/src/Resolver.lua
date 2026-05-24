--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Orient = require(ReplicatedStorage.Utilities.Orient)

local Types = require(script.Parent.Types)

type TCameraPose = Types.TCameraPose

local Resolver = {}

local function _BuildOffset(distance: number, yawDegrees: number, pitchDegrees: number): Vector3
	local yawRadians = math.rad(yawDegrees)
	local pitchRadians = math.rad(pitchDegrees)
	local rotation = Orient.FromPositionAndYaw(Vector3.zero, yawRadians) * CFrame.Angles(-pitchRadians, 0, 0)
	return rotation:VectorToWorldSpace(Vector3.new(0, 0, distance))
end

function Resolver.ResolveCameraCFrame(pose: TCameraPose): CFrame
	local cameraPosition = pose.FocusPoint + _BuildOffset(pose.Distance, pose.YawDegrees, pose.PitchDegrees)
	local cameraCFrame = Orient.BuildLookAt(cameraPosition, pose.FocusPoint)
	if cameraCFrame ~= nil then
		return cameraCFrame
	end

	return CFrame.new(cameraPosition)
end

return table.freeze(Resolver)
