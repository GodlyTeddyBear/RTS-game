--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TAIRuntimeContextCandidate = {
	AIRuntimeContext: any,
}

export type TAIRuntimeRuntimeCandidate = {
	RuntimeService: any,
	ActorRegistryService: any,
}

local HasConfigTable = Spec.new(
	"InvalidAIRuntimeContext",
	"AI runtime context config must be a table",
	function(candidate: TAIRuntimeContextCandidate): boolean
		return type(candidate.AIRuntimeContext) == "table"
	end
)

local HasRuntimeServiceField = Spec.new(
	"InvalidAIRuntimeContext",
	"AI runtime context RuntimeServiceField must be a non-empty string",
	function(candidate: TAIRuntimeContextCandidate): boolean
		local aiRuntimeContext = candidate.AIRuntimeContext
		return type(aiRuntimeContext) == "table"
			and type(aiRuntimeContext.RuntimeServiceField) == "string"
			and aiRuntimeContext.RuntimeServiceField ~= ""
	end
)

local HasActorRegistryServiceField = Spec.new(
	"InvalidAIRuntimeContext",
	"AI runtime context ActorRegistryServiceField must be a non-empty string",
	function(candidate: TAIRuntimeContextCandidate): boolean
		local aiRuntimeContext = candidate.AIRuntimeContext
		return type(aiRuntimeContext) == "table"
			and type(aiRuntimeContext.ActorRegistryServiceField) == "string"
			and aiRuntimeContext.ActorRegistryServiceField ~= ""
	end
)

local HasRuntimeServiceValidateSetup = Spec.new(
	"InvalidAIRuntimeRuntimeService",
	"AI runtime service must expose ValidateSetup",
	function(candidate: TAIRuntimeRuntimeCandidate): boolean
		return type(candidate.RuntimeService) == "table"
			and type((candidate.RuntimeService :: any).ValidateSetup) == "function"
	end
)

local HasActorRegistryServiceValidateSetup = Spec.new(
	"InvalidAIActorRegistryService",
	"AI actor registry service must expose ValidateSetup",
	function(candidate: TAIRuntimeRuntimeCandidate): boolean
		return type(candidate.ActorRegistryService) == "table"
			and type((candidate.ActorRegistryService :: any).ValidateSetup) == "function"
	end
)

return table.freeze({
	HasValidConfigShape = Spec.All({
		HasConfigTable,
		HasRuntimeServiceField,
		HasActorRegistryServiceField,
	}),
	HasRuntimeServiceValidateSetup = HasRuntimeServiceValidateSetup,
	HasActorRegistryServiceValidateSetup = HasActorRegistryServiceValidateSetup,
})
