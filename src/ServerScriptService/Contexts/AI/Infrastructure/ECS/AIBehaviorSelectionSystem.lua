--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Result = require(ReplicatedStorage.Utilities.Result)

local AIBehaviorSelectionSystem = {}
AIBehaviorSelectionSystem.__index = AIBehaviorSelectionSystem

function AIBehaviorSelectionSystem.new(entityFactory: any, entityContext: any, factProviderRegistry: any, decisionEvaluator: any)
	local self = setmetatable({}, AIBehaviorSelectionSystem)
	self._entityFactory = entityFactory
	self._entityContext = entityContext
	self._factProviderRegistry = factProviderRegistry
	self._decisionEvaluator = decisionEvaluator
	return self
end

function AIBehaviorSelectionSystem:Run()
	-- READS: AI.BehaviorTree [AUTHORITATIVE], AI.CurrentBehavior [AUTHORITATIVE], AI.BehaviorState [AUTHORITATIVE], AI.ActionState [AUTHORITATIVE]
	-- WRITES: AI.DesiredBehavior [AUTHORITATIVE], AI.ActionIntent [AUTHORITATIVE], AI.ActionIntentTag, AI.ActionDirtyTag, AI.BehaviorDirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = AISharedContract.FeatureName,
		Keys = {
			AISharedContract.Components.BehaviorTree,
			AISharedContract.Components.CurrentBehavior,
			AISharedContract.Components.BehaviorState,
			AISharedContract.Components.ActionState,
		},
	})
	if not queryResult.success then
		self:_MentionFailure("AI behavior selection query failed", queryResult)
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_EvaluateEntity(entity, now)
	end
end

function AIBehaviorSelectionSystem:_EvaluateEntity(entity: number, now: number)
	local contextResult = self:_BuildFactContext(entity, now)
	if not contextResult.success then
		self:_MentionFailure("AI fact context build failed", contextResult)
		return
	end

	local factsResult = self._factProviderRegistry:BuildFacts(contextResult.value)
	if not factsResult.success then
		self:_MentionFailure("AI fact provider build failed", factsResult)
		return
	end

	local evaluateResult = self._decisionEvaluator:Evaluate(entity, {
		Facts = factsResult.value,
		Now = now,
		DeltaTime = 0,
	})
	if not evaluateResult.success then
		self:_MentionFailure("AI scheduled entity evaluation failed", evaluateResult)
	end
end

function AIBehaviorSelectionSystem:_BuildFactContext(entity: number, now: number): Result.Result<any>
	local behaviorTree = self:_ReadComponent(entity, AISharedContract.Components.BehaviorTree)
	if not behaviorTree.success then
		return behaviorTree
	end
	local currentBehavior = self:_ReadComponent(entity, AISharedContract.Components.CurrentBehavior)
	if not currentBehavior.success then
		return currentBehavior
	end
	local behaviorState = self:_ReadComponent(entity, AISharedContract.Components.BehaviorState)
	if not behaviorState.success then
		return behaviorState
	end
	local actionState = self:_ReadComponent(entity, AISharedContract.Components.ActionState)
	if not actionState.success then
		return actionState
	end

	return Result.Ok({
		Entity = entity,
		EntityContext = self._entityContext,
		Now = now,
		BehaviorTree = self:_DeepClone(behaviorTree.value),
		CurrentBehavior = self:_DeepClone(currentBehavior.value),
		BehaviorState = self:_DeepClone(behaviorState.value),
		ActionState = self:_DeepClone(actionState.value),
	})
end

function AIBehaviorSelectionSystem:_ReadComponent(entity: number, key: string): Result.Result<any>
	return self._entityFactory:Get(entity, key, AISharedContract.FeatureName)
end

function AIBehaviorSelectionSystem:_DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_DeepClone(nestedValue)
	end
	return clone
end

function AIBehaviorSelectionSystem:_MentionFailure(message: string, result: Result.Result<any>)
	Result.MentionError("AIBehaviorSelectionSystem:Run", message, {
		CauseType = result.type,
		CauseMessage = result.message,
		Details = result.data,
	}, result.type)
end

return AIBehaviorSelectionSystem
