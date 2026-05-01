--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StructureTypes = require(ReplicatedStorage.Contexts.Structure.Types.StructureTypes)
local StructureRuntimeProfileRegistry = require(script.Parent.StructureRuntimeProfileRegistry)

type StructureType = StructureTypes.StructureType

local StructureAnimationStateResolver = {}

function StructureAnimationStateResolver.Resolve(
	structureType: StructureType?,
	combatAction: any
): (string, boolean)
	if structureType == nil then
		return "Idle", true
	end

	local profile = StructureRuntimeProfileRegistry.GetByStructureType(structureType)
	local actionId = if type(combatAction) == "table" then combatAction.CurrentActionId else nil
	local actionState = if type(combatAction) == "table" then combatAction.ActionState else nil

	local animationState = profile.DefaultAnimationState
	if type(actionId) == "string" and type(actionState) == "string" then
		local animationStatesByPhase = profile.AnimationByActionIdAndState[actionId]
		if animationStatesByPhase ~= nil then
			animationState = animationStatesByPhase[actionState] or profile.DefaultAnimationState
		end
	end

	local isLooping = profile.LoopingByAnimationState[animationState]
	if isLooping == nil then
		isLooping = true
	end

	return animationState, isLooping
end

return table.freeze(StructureAnimationStateResolver)
