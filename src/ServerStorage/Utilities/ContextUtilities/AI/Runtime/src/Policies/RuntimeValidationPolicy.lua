--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local ScratchRecycler = require(ServerStorage.Utilities.ContextUtilities.AI.src.Infrastructure.ScratchRecycler)
local RuntimeShapeSpec = require(script.Parent.Parent.Specs.RuntimeShapeSpec)
local HasValidActionStateShapeSpec = require(
	ServerStorage.Utilities.ContextUtilities.AI.AdapterFactory.src.Specs.HasValidActionStateShapeSpec
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

local function _CreateCandidateMap()
	return ScratchRecycler.AcquireMap()
end

local function _ReleaseCandidateMap(candidate: { [any]: any })
	ScratchRecycler.ReleaseMap(candidate)
end

function RuntimeValidationPolicy.CheckConfig(config: any)
	local candidate = _CreateCandidateMap()
	candidate.Config = config

	local result = RuntimeShapeSpec.HasValidConfigShape:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		"AiRuntime config is invalid"
	)

	for index, hook in ipairs(config.Hooks) do
		RuntimeValidationPolicy.CheckHook(hook, index)
	end
end

function RuntimeValidationPolicy.CheckHook(hook: any, index: number)
	local candidate = _CreateCandidateMap()
	candidate.Hook = hook

	local result = RuntimeShapeSpec.HasValidHookShape:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("AiRuntime hook #%d is invalid"):format(index)
	)
end

function RuntimeValidationPolicy.CheckActorType(actorType: any)
	local candidate = _CreateCandidateMap()
	candidate.ActorType = actorType

	local result = RuntimeShapeSpec.HasValidActorType:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		"AiRuntime actorType is invalid"
	)
end

function RuntimeValidationPolicy.CheckActorAdapter(actorType: string, adapter: any)
	local adapterCandidate = _CreateCandidateMap()
	adapterCandidate.Adapter = adapter

	local adapterResult = RuntimeShapeSpec.HasAdapterTable:IsSatisfiedBy(adapterCandidate)
	_ReleaseCandidateMap(adapterCandidate)
	_AssertSatisfied(
		adapterResult,
		("AiRuntime actor adapter '%s' is invalid"):format(actorType)
	)

	for _, methodName in ipairs(REQUIRED_ADAPTER_METHODS) do
		local methodCandidate = _CreateCandidateMap()
		methodCandidate.Adapter = adapter
		methodCandidate.MethodName = methodName

		local methodResult = RuntimeShapeSpec.HasRequiredAdapterMethod:IsSatisfiedBy(methodCandidate)
		_ReleaseCandidateMap(methodCandidate)
		_AssertSatisfied(
			methodResult,
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
	local frameContextCandidate = _CreateCandidateMap()
	frameContextCandidate.FrameContext = frameContext

	local frameContextResult = RuntimeShapeSpec.HasValidFrameContextShape:IsSatisfiedBy(frameContextCandidate)
	_ReleaseCandidateMap(frameContextCandidate)
	_AssertSatisfied(
		frameContextResult,
		"AiRuntime frameContext is invalid"
	)

	if frameContext.ActorTypes ~= nil then
		for index, actorType in ipairs(frameContext.ActorTypes) do
			local actorTypeCandidate = _CreateCandidateMap()
			actorTypeCandidate.ActorType = actorType

			local actorTypeResult = RuntimeShapeSpec.HasValidActorType:IsSatisfiedBy(actorTypeCandidate)
			_ReleaseCandidateMap(actorTypeCandidate)
			_AssertSatisfied(
				actorTypeResult,
				("AiRuntime frameContext.ActorTypes[%d] must be a non-empty string"):format(index)
			)
		end
	end
end

function RuntimeValidationPolicy.CheckMonotonicFrameTime(currentTime: number, lastFrameTime: number?)
	local candidate = _CreateCandidateMap()
	candidate.CurrentTime = currentTime
	candidate.LastFrameTime = lastFrameTime

	local result = RuntimeShapeSpec.HasMonotonicFrameTime:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		"AiRuntime frame time moved backward"
	)
end

function RuntimeValidationPolicy.CheckQueryActiveEntitiesResult(actorType: string, entities: any)
	local candidate = _CreateCandidateMap()
	candidate.Entities = entities

	local result = RuntimeShapeSpec.HasEntityArrayTable:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("AiRuntime adapter '%s' QueryActiveEntities must return an array"):format(actorType)
	)
end

function RuntimeValidationPolicy.CheckEntityId(actorType: string, entity: any, sourceLabel: string)
	local candidate = _CreateCandidateMap()
	candidate.Entity = entity

	local result = RuntimeShapeSpec.HasValidEntityId:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("AiRuntime %s for actor type '%s' returned an invalid entity id"):format(sourceLabel, actorType)
	)
end

function RuntimeValidationPolicy.CheckActionState(actionState: any, sourceLabel: string)
	local candidate = _CreateCandidateMap()
	candidate.ActionState = actionState

	local result = HasValidActionStateShapeSpec.HasValidActionStateShape:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("%s received an invalid action-state payload"):format(sourceLabel)
	)
end

function RuntimeValidationPolicy.CheckBehaviorTree(actorType: string, entity: number, behaviorTree: any)
	local candidate = _CreateCandidateMap()
	candidate.BehaviorTree = behaviorTree

	local result = RuntimeShapeSpec.HasValidBehaviorTreeShape:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("AiRuntime actor type '%s' entity %d returned an invalid behavior tree"):format(actorType, entity)
	)
end

function RuntimeValidationPolicy.CheckShouldEvaluateResult(actorType: string, entity: number, result: any)
	local candidate = _CreateCandidateMap()
	candidate.Value = result

	local boolResult = RuntimeShapeSpec.HasBooleanResult:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		boolResult,
		("AiRuntime actor type '%s' entity %d ShouldEvaluate must return a boolean"):format(actorType, entity)
	)
end

function RuntimeValidationPolicy.CheckHookContribution(index: number, contribution: any)
	local candidate = _CreateCandidateMap()
	candidate.Contribution = contribution

	local result = RuntimeShapeSpec.HasValidHookContributionShape:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("AiRuntime hook #%d returned an invalid contribution"):format(index)
	)
end

function RuntimeValidationPolicy.CheckBehaviorContextReservedKeys(index: number, behaviorContext: any)
	local candidate = _CreateCandidateMap()
	candidate.BehaviorContext = behaviorContext

	local result = RuntimeShapeSpec.HasNoReservedBehaviorContextKeys:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("AiRuntime hook #%d attempted to overwrite reserved tree-context keys"):format(index)
	)
end

function RuntimeValidationPolicy.CheckActorLabel(actorType: string, actorLabel: any)
	local candidate = _CreateCandidateMap()
	candidate.ActorLabel = actorLabel

	local result = RuntimeShapeSpec.HasValidActorLabel:IsSatisfiedBy(candidate)
	_ReleaseCandidateMap(candidate)
	_AssertSatisfied(
		result,
		("AiRuntime actor adapter '%s' returned an invalid actor label"):format(actorType)
	)
end

return table.freeze(RuntimeValidationPolicy)
