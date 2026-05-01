--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RuntimeShapeSpec = require(script.Parent.Parent.Specs.RuntimeShapeSpec)
local HasValidActionStateShapeSpec = require(
	ReplicatedStorage.Utilities.AI.AdapterFactory.src.Specs.HasValidActionStateShapeSpec
)

local REQUIRED_ADAPTER_METHODS = table.freeze({
	"QueryActiveEntities",
	"GetCompiledBehaviorTree",
	"GetActionState",
	"SetActionState",
	"ClearActionState",
	"SetPendingAction",
	"UpdateLastTickTime",
	"ShouldEvaluate",
})

local RuntimeValidationPolicy = {}

local function _BuildFailureMessage(prefix: string, result: any): string
	if type(result) == "table" and result.message ~= nil then
		return ("%s: %s"):format(prefix, tostring(result.message))
	end

	return prefix
end

local function _AssertSatisfied(result: any, prefix: string)
	assert(result.success, _BuildFailureMessage(prefix, result))
end

function RuntimeValidationPolicy.CheckConfig(config: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidConfigShape:IsSatisfiedBy({
			Config = config,
		}),
		"AiRuntime config is invalid"
	)

	for index, hook in ipairs(config.Hooks) do
		RuntimeValidationPolicy.CheckHook(hook, index)
	end
end

function RuntimeValidationPolicy.CheckHook(hook: any, index: number)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidHookShape:IsSatisfiedBy({
			Hook = hook,
		}),
		("AiRuntime hook #%d is invalid"):format(index)
	)
end

function RuntimeValidationPolicy.CheckActorType(actorType: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidActorType:IsSatisfiedBy({
			ActorType = actorType,
		}),
		"AiRuntime actorType is invalid"
	)
end

function RuntimeValidationPolicy.CheckActorAdapter(actorType: string, adapter: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasAdapterTable:IsSatisfiedBy({
			Adapter = adapter,
		}),
		("AiRuntime actor adapter '%s' is invalid"):format(actorType)
	)

	for _, methodName in ipairs(REQUIRED_ADAPTER_METHODS) do
		_AssertSatisfied(
			RuntimeShapeSpec.HasRequiredAdapterMethod:IsSatisfiedBy({
				Adapter = adapter,
				MethodName = methodName,
			}),
			("AiRuntime actor adapter '%s' must expose %s"):format(actorType, methodName)
		)
	end

	local getActorLabel = (adapter :: any).GetActorLabel
	if getActorLabel ~= nil then
		assert(
			type(getActorLabel) == "function",
			("AiRuntime actor adapter '%s' GetActorLabel must be a function"):format(actorType)
		)
	end
end

function RuntimeValidationPolicy.CheckFrameContext(frameContext: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidFrameContextShape:IsSatisfiedBy({
			FrameContext = frameContext,
		}),
		"AiRuntime frameContext is invalid"
	)

	if frameContext.ActorTypes ~= nil then
		for index, actorType in ipairs(frameContext.ActorTypes) do
			_AssertSatisfied(
				RuntimeShapeSpec.HasValidActorType:IsSatisfiedBy({
					ActorType = actorType,
				}),
				("AiRuntime frameContext.ActorTypes[%d] must be a non-empty string"):format(index)
			)
		end
	end
end

function RuntimeValidationPolicy.CheckMonotonicFrameTime(currentTime: number, lastFrameTime: number?)
	_AssertSatisfied(
		RuntimeShapeSpec.HasMonotonicFrameTime:IsSatisfiedBy({
			CurrentTime = currentTime,
			LastFrameTime = lastFrameTime,
		}),
		"AiRuntime frame time moved backward"
	)
end

function RuntimeValidationPolicy.CheckQueryActiveEntitiesResult(actorType: string, entities: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasEntityArrayTable:IsSatisfiedBy({
			Entities = entities,
		}),
		("AiRuntime adapter '%s' QueryActiveEntities must return an array"):format(actorType)
	)
end

function RuntimeValidationPolicy.CheckEntityId(actorType: string, entity: any, sourceLabel: string)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidEntityId:IsSatisfiedBy({
			Entity = entity,
		}),
		("AiRuntime %s for actor type '%s' returned an invalid entity id"):format(sourceLabel, actorType)
	)
end

function RuntimeValidationPolicy.CheckActionState(actionState: any, sourceLabel: string)
	_AssertSatisfied(
		HasValidActionStateShapeSpec.HasValidActionStateShape:IsSatisfiedBy({
			ActionState = actionState,
		}),
		("%s received an invalid action-state payload"):format(sourceLabel)
	)
end

function RuntimeValidationPolicy.CheckBehaviorTree(actorType: string, entity: number, behaviorTree: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidBehaviorTreeShape:IsSatisfiedBy({
			BehaviorTree = behaviorTree,
		}),
		("AiRuntime actor type '%s' entity %d returned an invalid behavior tree"):format(actorType, entity)
	)
end

function RuntimeValidationPolicy.CheckShouldEvaluateResult(actorType: string, entity: number, result: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasBooleanResult:IsSatisfiedBy({
			Value = result,
		}),
		("AiRuntime actor type '%s' entity %d ShouldEvaluate must return a boolean"):format(actorType, entity)
	)
end

function RuntimeValidationPolicy.CheckHookContribution(index: number, contribution: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidHookContributionShape:IsSatisfiedBy({
			Contribution = contribution,
		}),
		("AiRuntime hook #%d returned an invalid contribution"):format(index)
	)
end

function RuntimeValidationPolicy.CheckBehaviorContextReservedKeys(index: number, behaviorContext: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasNoReservedBehaviorContextKeys:IsSatisfiedBy({
			BehaviorContext = behaviorContext,
		}),
		("AiRuntime hook #%d attempted to overwrite reserved tree-context keys"):format(index)
	)
end

function RuntimeValidationPolicy.CheckActorLabel(actorType: string, actorLabel: any)
	_AssertSatisfied(
		RuntimeShapeSpec.HasValidActorLabel:IsSatisfiedBy({
			ActorLabel = actorLabel,
		}),
		("AiRuntime actor adapter '%s' returned an invalid actor label"):format(actorType)
	)
end

return table.freeze(RuntimeValidationPolicy)
