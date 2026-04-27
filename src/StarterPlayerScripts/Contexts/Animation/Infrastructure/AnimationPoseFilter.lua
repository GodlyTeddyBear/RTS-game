--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Contexts.Animation.Types.AnimationTypes)

type TAnimationPreset = Types.TAnimationPreset

local AnimationPoseFilter = {}

function AnimationPoseFilter.IsPoseAllowed(preset: TAnimationPreset, pose: string): boolean
	local filterMode = preset.PoseFilterMode
	local poseFilter = preset.PoseFilter

	if filterMode == "Whitelist" then
		return poseFilter ~= nil and poseFilter[pose] == true
	end

	if filterMode == "Blacklist" then
		return poseFilter == nil or poseFilter[pose] ~= true
	end

	return true
end

return table.freeze(AnimationPoseFilter)
