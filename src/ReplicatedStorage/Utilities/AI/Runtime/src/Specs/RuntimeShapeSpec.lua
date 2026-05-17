--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)

export type TConfigCandidate = {
	Config: any,
}

export type THookCandidate = {
	Hook: any,
}

export type TActorTypeCandidate = {
	ActorType: any,
}

export type TAdapterCandidate = {
	Adapter: any,
	MethodName: string?,
}

export type TFrameContextCandidate = {
	FrameContext: any,
}

export type TFrameTimeCandidate = {
	CurrentTime: number,
	LastFrameTime: number?,
}

export type TEntityArrayCandidate = {
	Entities: any,
}

export type TEntityCandidate = {
	Entity: any,
}

export type TBehaviorTreeCandidate = {
	BehaviorTree: any,
}

export type TBooleanCandidate = {
	Value: any,
}

export type THookContributionCandidate = {
	Contribution: any,
}

export type TBehaviorContextCandidate = {
	BehaviorContext: any,
}

export type TActorLabelCandidate = {
	ActorLabel: any,
}

local RESERVED_BEHAVIOR_CONTEXT_KEYS = table.freeze({
	Entity = true,
	ActorType = true,
	Facts = true,
	ActionFactory = true,
})

local function _IsFiniteNumber(value: number): boolean
	return value == value and value > -math.huge and value < math.huge
end

local HasConfigTable = Spec.new(
	"InvalidRuntimeConfig",
	"AiRuntime config must be a table",
	function(candidate: TConfigCandidate): boolean
		return type(candidate.Config) == "table"
	end
)

local HasConditionsTable = Spec.new(
	"InvalidRuntimeConfig",
	"AiRuntime config.Conditions must be a table",
	function(candidate: TConfigCandidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or type(config.Conditions) == "table"
	end
)

local HasCommandsTable = Spec.new(
	"InvalidRuntimeConfig",
	"AiRuntime config.Commands must be a table",
	function(candidate: TConfigCandidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or type(config.Commands) == "table"
	end
)

local HasHooksTable = Spec.new(
	"InvalidRuntimeConfig",
	"AiRuntime config.Hooks must be a table",
	function(candidate: TConfigCandidate): boolean
		local config = candidate.Config
		return type(config) ~= "table" or type(config.Hooks) == "table"
	end
)

local HasErrorSinkFunctionOrNil = Spec.new(
	"InvalidRuntimeConfig",
	"AiRuntime config.ErrorSink must be a function when present",
	function(candidate: TConfigCandidate): boolean
		local config = candidate.Config
		if type(config) ~= "table" then
			return true
		end

		local errorSink = config.ErrorSink
		return errorSink == nil or type(errorSink) == "function"
	end
)

local HasDirectCombatHookFlagBooleanOrNil = Spec.new(
	"InvalidRuntimeConfig",
	"AiRuntime config.UseDirectCombatHookPath must be a boolean when present",
	function(candidate: TConfigCandidate): boolean
		local config = candidate.Config
		if type(config) ~= "table" then
			return true
		end

		local flag = config.UseDirectCombatHookPath
		return flag == nil or type(flag) == "boolean"
	end
)

local HasCachedActiveProviderFlagBooleanOrNil = Spec.new(
	"InvalidRuntimeConfig",
	"AiRuntime config.UseCachedActiveEntityProvider must be a boolean when present",
	function(candidate: TConfigCandidate): boolean
		local config = candidate.Config
		if type(config) ~= "table" then
			return true
		end

		local flag = config.UseCachedActiveEntityProvider
		return flag == nil or type(flag) == "boolean"
	end
)

local HasHookTable = Spec.new(
	"InvalidRuntimeHook",
	"AiRuntime hook must be a table",
	function(candidate: THookCandidate): boolean
		return type(candidate.Hook) == "table"
	end
)

local HasHookUseFunction = Spec.new(
	"InvalidRuntimeHook",
	"AiRuntime hook must expose Use",
	function(candidate: THookCandidate): boolean
		local hook = candidate.Hook
		return type(hook) ~= "table" or type(hook.Use) == "function"
	end
)

local HasActorTypeString = Spec.new(
	"InvalidActorType",
	"AiRuntime actorType must be a non-empty string",
	function(candidate: TActorTypeCandidate): boolean
		local actorType = candidate.ActorType
		return type(actorType) == "string" and #actorType > 0
	end
)

local HasAdapterTable = Spec.new(
	"InvalidActorAdapter",
	"AiRuntime actor adapter must be a table",
	function(candidate: TAdapterCandidate): boolean
		return type(candidate.Adapter) == "table"
	end
)

local HasRequiredAdapterMethod = Spec.new(
	"InvalidActorAdapter",
	"AiRuntime actor adapter is missing a required method",
	function(candidate: TAdapterCandidate): boolean
		local adapter = candidate.Adapter
		local methodName = candidate.MethodName
		return type(adapter) ~= "table" or (methodName ~= nil and type((adapter :: any)[methodName]) == "function")
	end
)

local HasFrameContextTable = Spec.new(
	"InvalidFrameContext",
	"AiRuntime frameContext must be a table",
	function(candidate: TFrameContextCandidate): boolean
		return type(candidate.FrameContext) == "table"
	end
)

local HasCurrentTimeNumber = Spec.new(
	"InvalidFrameContext",
	"AiRuntime frameContext.CurrentTime must be a finite number",
	function(candidate: TFrameContextCandidate): boolean
		local frameContext = candidate.FrameContext
		return type(frameContext) ~= "table"
			or (type(frameContext.CurrentTime) == "number" and _IsFiniteNumber(frameContext.CurrentTime))
	end
)

local HasTickIdNumber = Spec.new(
	"InvalidFrameContext",
	"AiRuntime frameContext.TickId must be a non-negative integer",
	function(candidate: TFrameContextCandidate): boolean
		local frameContext = candidate.FrameContext
		return type(frameContext) ~= "table"
			or (
				type(frameContext.TickId) == "number"
				and _IsFiniteNumber(frameContext.TickId)
				and frameContext.TickId >= 0
				and math.floor(frameContext.TickId) == frameContext.TickId
			)
	end
)

local HasDeltaTimeNumberOrNil = Spec.new(
	"InvalidFrameContext",
	"AiRuntime frameContext.DeltaTime must be a finite non-negative number when present",
	function(candidate: TFrameContextCandidate): boolean
		local frameContext = candidate.FrameContext
		if type(frameContext) ~= "table" then
			return true
		end

		local deltaTime = frameContext.DeltaTime
		return deltaTime == nil or (type(deltaTime) == "number" and _IsFiniteNumber(deltaTime) and deltaTime >= 0)
	end
)

local HasServicesTableOrNil = Spec.new(
	"InvalidFrameContext",
	"AiRuntime frameContext.Services must be a table when present",
	function(candidate: TFrameContextCandidate): boolean
		local frameContext = candidate.FrameContext
		if type(frameContext) ~= "table" then
			return true
		end

		local services = frameContext.Services
		return services == nil or type(services) == "table"
	end
)

local HasActorTypesArrayOrNil = Spec.new(
	"InvalidFrameContext",
	"AiRuntime frameContext.ActorTypes must be a table when present",
	function(candidate: TFrameContextCandidate): boolean
		local frameContext = candidate.FrameContext
		if type(frameContext) ~= "table" then
			return true
		end

		local actorTypes = frameContext.ActorTypes
		return actorTypes == nil or type(actorTypes) == "table"
	end
)

local HasMonotonicFrameTime = Spec.new(
	"NonMonotonicFrameTime",
	"AiRuntime frameContext.CurrentTime must not move backward between frames",
	function(candidate: TFrameTimeCandidate): boolean
		local lastFrameTime = candidate.LastFrameTime
		return lastFrameTime == nil or candidate.CurrentTime >= lastFrameTime
	end
)

local HasEntityArrayTable = Spec.new(
	"InvalidEntityQueryResult",
	"AiRuntime QueryActiveEntities must return an array",
	function(candidate: TEntityArrayCandidate): boolean
		return type(candidate.Entities) == "table"
	end
)

local HasValidEntityId = Spec.new(
	"InvalidRuntimeEntity",
	"AiRuntime runtime entities must be positive integers",
	function(candidate: TEntityCandidate): boolean
		local entity = candidate.Entity
		return type(entity) == "number" and entity > 0 and math.floor(entity) == entity
	end
)

local HasValidBehaviorTreeShape = Spec.new(
	"InvalidBehaviorTree",
	"AiRuntime behavior tree must be nil or expose run",
	function(candidate: TBehaviorTreeCandidate): boolean
		local behaviorTree = candidate.BehaviorTree
		return behaviorTree == nil or (type(behaviorTree) == "table" and type((behaviorTree :: any).run) == "function")
	end
)

local HasBooleanResult = Spec.new(
	"InvalidRuntimeBoolean",
	"AiRuntime result must be a boolean",
	function(candidate: TBooleanCandidate): boolean
		return type(candidate.Value) == "boolean"
	end
)

local HasHookContributionTableOrNil = Spec.new(
	"InvalidHookContribution",
	"AiRuntime hook contribution must be a table or nil",
	function(candidate: THookContributionCandidate): boolean
		local contribution = candidate.Contribution
		return contribution == nil or type(contribution) == "table"
	end
)

local HasFactsBucketTableOrNil = Spec.new(
	"InvalidHookContribution",
	"AiRuntime hook contribution Facts must be a table when present",
	function(candidate: THookContributionCandidate): boolean
		local contribution = candidate.Contribution
		if contribution == nil or type(contribution) ~= "table" then
			return true
		end

		local facts = contribution.Facts
		return facts == nil or type(facts) == "table"
	end
)

local HasBehaviorContextBucketTableOrNil = Spec.new(
	"InvalidHookContribution",
	"AiRuntime hook contribution BehaviorContext must be a table when present",
	function(candidate: THookContributionCandidate): boolean
		local contribution = candidate.Contribution
		if contribution == nil or type(contribution) ~= "table" then
			return true
		end

		local behaviorContext = contribution.BehaviorContext
		return behaviorContext == nil or type(behaviorContext) == "table"
	end
)

local HasServicesBucketTableOrNil = Spec.new(
	"InvalidHookContribution",
	"AiRuntime hook contribution Services must be a table when present",
	function(candidate: THookContributionCandidate): boolean
		local contribution = candidate.Contribution
		if contribution == nil or type(contribution) ~= "table" then
			return true
		end

		local services = contribution.Services
		return services == nil or type(services) == "table"
	end
)

local HasNoReservedBehaviorContextKeys = Spec.new(
	"ReservedBehaviorContextKey",
	"AiRuntime hook contribution BehaviorContext must not overwrite reserved tree-context keys",
	function(candidate: TBehaviorContextCandidate): boolean
		local behaviorContext = candidate.BehaviorContext
		if behaviorContext == nil then
			return true
		end

		if type(behaviorContext) ~= "table" then
			return false
		end

		for key in pairs(behaviorContext) do
			if RESERVED_BEHAVIOR_CONTEXT_KEYS[key] == true then
				return false
			end
		end

		return true
	end
)

local HasValidActorLabel = Spec.new(
	"InvalidActorLabel",
	"AiRuntime actor label must be a non-empty string when present",
	function(candidate: TActorLabelCandidate): boolean
		local actorLabel = candidate.ActorLabel
		return actorLabel == nil or (type(actorLabel) == "string" and #actorLabel > 0)
	end
)

return table.freeze({
	HasValidConfigShape = Spec.All({
		HasConfigTable,
		HasConditionsTable,
		HasCommandsTable,
		HasHooksTable,
		HasErrorSinkFunctionOrNil,
		HasDirectCombatHookFlagBooleanOrNil,
		HasCachedActiveProviderFlagBooleanOrNil,
	}),
	HasValidHookShape = HasHookTable:And(HasHookUseFunction),
	HasValidActorType = HasActorTypeString,
	HasAdapterTable = HasAdapterTable,
	HasRequiredAdapterMethod = HasRequiredAdapterMethod,
	HasValidFrameContextShape = Spec.All({
		HasFrameContextTable,
		HasCurrentTimeNumber,
		HasTickIdNumber,
		HasDeltaTimeNumberOrNil,
		HasServicesTableOrNil,
		HasActorTypesArrayOrNil,
	}),
	HasMonotonicFrameTime = HasMonotonicFrameTime,
	HasEntityArrayTable = HasEntityArrayTable,
	HasValidEntityId = HasValidEntityId,
	HasValidBehaviorTreeShape = HasValidBehaviorTreeShape,
	HasBooleanResult = HasBooleanResult,
	HasValidHookContributionShape = Spec.All({
		HasHookContributionTableOrNil,
		HasFactsBucketTableOrNil,
		HasBehaviorContextBucketTableOrNil,
		HasServicesBucketTableOrNil,
	}),
	HasNoReservedBehaviorContextKeys = HasNoReservedBehaviorContextKeys,
	HasValidActorLabel = HasValidActorLabel,
})
