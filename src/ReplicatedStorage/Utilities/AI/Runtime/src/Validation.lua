--!strict

local Types = require(script.Parent.Types)
local RuntimeValidationPolicy = require(script.Parent.Policies.RuntimeValidationPolicy)

type TConfig = Types.TConfig
type TActorAdapter = Types.TActorAdapter
type TFrameContext = Types.TFrameContext

--[=[
	@class AiRuntimeValidation
	Centralizes runtime configuration, adapter, and frame-input validation for `AiRuntime`.
	@server
	@client
]=]

local Validation = {}

function Validation.ValidateConfig(config: TConfig)
	RuntimeValidationPolicy.CheckConfig(config)
end

function Validation.ValidateActorType(actorType: string)
	RuntimeValidationPolicy.CheckActorType(actorType)
end

function Validation.ValidateActorAdapter(actorType: string, adapter: TActorAdapter)
	RuntimeValidationPolicy.CheckActorAdapter(actorType, adapter)
end

function Validation.ValidateFrameContext(frameContext: TFrameContext)
	RuntimeValidationPolicy.CheckFrameContext(frameContext)
end

function Validation.ValidateMonotonicFrameTime(currentTime: number, lastFrameTime: number?)
	RuntimeValidationPolicy.CheckMonotonicFrameTime(currentTime, lastFrameTime)
end

function Validation.ValidateQueryActiveEntitiesResult(actorType: string, entities: any)
	RuntimeValidationPolicy.CheckQueryActiveEntitiesResult(actorType, entities)
end

function Validation.ValidateEntityId(actorType: string, entity: any, sourceLabel: string)
	RuntimeValidationPolicy.CheckEntityId(actorType, entity, sourceLabel)
end

function Validation.ValidateActionState(actionState: any, sourceLabel: string)
	RuntimeValidationPolicy.CheckActionState(actionState, sourceLabel)
end

function Validation.ValidateBehaviorTree(actorType: string, entity: number, behaviorTree: any)
	RuntimeValidationPolicy.CheckBehaviorTree(actorType, entity, behaviorTree)
end

function Validation.ValidateShouldEvaluateResult(actorType: string, entity: number, result: any)
	RuntimeValidationPolicy.CheckShouldEvaluateResult(actorType, entity, result)
end

function Validation.ValidateHookContribution(index: number, contribution: any)
	RuntimeValidationPolicy.CheckHookContribution(index, contribution)
end

function Validation.ValidateBehaviorContextReservedKeys(index: number, behaviorContext: any)
	RuntimeValidationPolicy.CheckBehaviorContextReservedKeys(index, behaviorContext)
end

function Validation.ValidateActorLabel(actorType: string, actorLabel: any)
	RuntimeValidationPolicy.CheckActorLabel(actorType, actorLabel)
end

return table.freeze(Validation)
