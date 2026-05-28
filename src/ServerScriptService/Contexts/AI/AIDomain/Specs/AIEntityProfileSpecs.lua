--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Spec = require(ReplicatedStorage.Utilities.Specification)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TAIEntityProfileCandidate = {
	Profile: any,
	DefinitionIdValid: boolean,
	DefinitionRegistered: boolean,
	TickIntervalValid: boolean,
	InitialBehaviorIdValid: boolean,
	NodePathValid: boolean,
	ActionStateStatusValid: boolean,
}

local HasProfileTable = Spec.new("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, function(candidate: TAIEntityProfileCandidate)
	return type(candidate.Profile) == "table"
end)

local HasDefinitionId = Spec.new("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, function(candidate: TAIEntityProfileCandidate)
	return candidate.DefinitionIdValid
end)

local HasRegisteredDefinition =
	Spec.new("UnknownBehaviorDefinition", Errors.UNKNOWN_BEHAVIOR_DEFINITION, function(candidate: TAIEntityProfileCandidate)
		return candidate.DefinitionRegistered
	end)

local HasValidTickInterval =
	Spec.new("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, function(candidate: TAIEntityProfileCandidate)
		return candidate.TickIntervalValid
	end)

local HasValidInitialBehaviorId =
	Spec.new("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, function(candidate: TAIEntityProfileCandidate)
		return candidate.InitialBehaviorIdValid
	end)

local HasValidNodePath =
	Spec.new("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, function(candidate: TAIEntityProfileCandidate)
		return candidate.NodePathValid
	end)

local HasValidActionStateStatus =
	Spec.new("InvalidEntityProfile", Errors.INVALID_ENTITY_PROFILE, function(candidate: TAIEntityProfileCandidate)
		return candidate.ActionStateStatusValid
	end)

return table.freeze({
	HasProfileTable = HasProfileTable,
	HasDefinitionId = HasDefinitionId,
	HasRegisteredDefinition = HasRegisteredDefinition,
	HasValidTickInterval = HasValidTickInterval,
	HasValidInitialBehaviorId = HasValidInitialBehaviorId,
	HasValidNodePath = HasValidNodePath,
	HasValidActionStateStatus = HasValidActionStateStatus,
	CanSetupEntityAI = Spec.All({
		HasProfileTable,
		HasDefinitionId,
		HasRegisteredDefinition,
		HasValidTickInterval,
		HasValidInitialBehaviorId,
		HasValidNodePath,
		HasValidActionStateStatus,
	}),
	ValidActionStatuses = AISharedContract.ActionStatus,
	ValidBehaviorStatuses = AISharedContract.BehaviorStatus,
})
