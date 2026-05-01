--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TActionStateCandidate = {
	ActionState: any,
}

local HasActionStateTableOrNil = Spec.new(
	"InvalidActionStateShape",
	"AiAdapterFactory action state must be a table or nil",
	function(candidate: TActionStateCandidate): boolean
		local actionState = candidate.ActionState
		return actionState == nil or type(actionState) == "table"
	end
)

local HasValidPendingActionId = Spec.new(
	"InvalidActionStateShape",
	"AiAdapterFactory action state field 'PendingActionId' must be a string when present",
	function(candidate: TActionStateCandidate): boolean
		local actionState = candidate.ActionState
		if actionState == nil or type(actionState) ~= "table" then
			return true
		end

		local value = actionState.PendingActionId
		return value == nil or type(value) == "string"
	end
)

local HasValidCurrentActionId = Spec.new(
	"InvalidActionStateShape",
	"AiAdapterFactory action state field 'CurrentActionId' must be a string when present",
	function(candidate: TActionStateCandidate): boolean
		local actionState = candidate.ActionState
		if actionState == nil or type(actionState) ~= "table" then
			return true
		end

		local value = actionState.CurrentActionId
		return value == nil or type(value) == "string"
	end
)

local HasValidActionStateField = Spec.new(
	"InvalidActionStateShape",
	"AiAdapterFactory action state field 'ActionState' must be a string when present",
	function(candidate: TActionStateCandidate): boolean
		local actionState = candidate.ActionState
		if actionState == nil or type(actionState) ~= "table" then
			return true
		end

		local value = actionState.ActionState
		return value == nil or type(value) == "string"
	end
)

local HasValidActionStateShape = HasActionStateTableOrNil
	:And(HasValidPendingActionId)
	:And(HasValidCurrentActionId)
	:And(HasValidActionStateField)

return table.freeze({
	HasValidActionStateShape = HasValidActionStateShape,
})
