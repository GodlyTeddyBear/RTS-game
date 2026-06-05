--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

type TAIEntityEvaluationOptions = AISharedContract.TAIEntityEvaluationOptions
type TAIEntityEvaluationResult = AISharedContract.TAIEntityEvaluationResult

local AIEntityDecisionEvaluator = {}
AIEntityDecisionEvaluator.__index = AIEntityDecisionEvaluator

function AIEntityDecisionEvaluator.new()
	return setmetatable({}, AIEntityDecisionEvaluator)
end

function AIEntityDecisionEvaluator:Init(registry: any, _name: string)
	self._behaviorRegistry = registry:Get("AIBehaviorDefinitionRegistry")
end

function AIEntityDecisionEvaluator:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
	assert(self._entityContext ~= nil, "AIEntityDecisionEvaluator missing EntityContext in Start")
end

function AIEntityDecisionEvaluator:Evaluate(
	entity: number,
	options: TAIEntityEvaluationOptions?
): Result.Result<TAIEntityEvaluationResult>
	return Result.Catch(function()
		local now = self:_ResolveNow(options)
		local entityResult = self:_EnsureEntityExists(entity)
		if not entityResult.success then
			return entityResult
		end

		local componentsResult = self:_ReadAIComponents(entity)
		if not componentsResult.success then
			return componentsResult
		end

		local components = componentsResult.value
		local definitionId = components.BehaviorTree.DefinitionId
		local skipResult = self:_CheckTickInterval(components.BehaviorTree, components.CurrentBehavior, options, now)
		if not skipResult.success then
			return skipResult
		end
		if skipResult.value ~= nil then
			return Result.Ok(skipResult.value)
		end

		local definitionRecord = self._behaviorRegistry:GetDefinition(definitionId)
		if definitionRecord == nil then
			return Result.Err("UnknownBehaviorDefinition", Errors.UNKNOWN_BEHAVIOR_DEFINITION, {
				Entity = entity,
				DefinitionId = definitionId,
			})
		end

		local context = self:_BuildEvaluationContext(entity, components, options, now)
		local runResult = self:_RunBehaviorTree(definitionRecord.CompiledTree, context, entity, definitionId)
		if not runResult.success then
			return runResult
		end

		local actionIntentResult = self:_NormalizeActionIntent(entity, context, now)
		if not actionIntentResult.success then
			return actionIntentResult
		end

		local actionIntent = actionIntentResult.value
		if actionIntent ~= nil then
			local writeResult = self:_WriteActionDecision(entity, actionIntent, now)
			if not writeResult.success then
				return writeResult
			end

			return Result.Ok({
				Evaluated = true,
				DefinitionId = definitionId,
				ActionIntent = actionIntent,
				BehaviorId = actionIntent.ActionId,
			})
		end

		local clearResult = self:_ClearActionDecision(entity, components.CurrentBehavior, now)
		if not clearResult.success then
			return clearResult
		end

		return Result.Ok({
			Evaluated = true,
			DefinitionId = definitionId,
			ActionIntent = nil,
			BehaviorId = self:_ResolveCurrentBehaviorId(components.CurrentBehavior),
		})
	end, "AIEntityDecisionEvaluator:Evaluate")
end

function AIEntityDecisionEvaluator:_ResolveNow(options: TAIEntityEvaluationOptions?): number
	if type(options) == "table" and type(options.Now) == "number" then
		return options.Now
	end

	return os.clock()
end

function AIEntityDecisionEvaluator:_EnsureEntityExists(entity: number): Result.Result<boolean>
	if type(entity) ~= "number" then
		return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
			Entity = entity,
		})
	end

	local hasResult = self._entityContext:Has(entity, "Identity", "Entity")
	if not hasResult.success then
		return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
			Entity = entity,
			CauseType = hasResult.type,
			CauseMessage = hasResult.message,
			Details = hasResult.data,
		})
	end

	if hasResult.value ~= true then
		return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
			Entity = entity,
		})
	end

	return Result.Ok(true)
end

function AIEntityDecisionEvaluator:_ReadAIComponents(entity: number): Result.Result<any>
	local behaviorTree = self:_ReadRequiredComponent(entity, AISharedContract.Components.BehaviorTree)
	if not behaviorTree.success then
		return behaviorTree
	end
	local currentBehavior = self:_ReadRequiredComponent(entity, AISharedContract.Components.CurrentBehavior)
	if not currentBehavior.success then
		return currentBehavior
	end
	local behaviorState = self:_ReadRequiredComponent(entity, AISharedContract.Components.BehaviorState)
	if not behaviorState.success then
		return behaviorState
	end
	local actionState = self:_ReadRequiredComponent(entity, AISharedContract.Components.ActionState)
	if not actionState.success then
		return actionState
	end

	if type(behaviorTree.value.DefinitionId) ~= "string" or behaviorTree.value.DefinitionId == "" then
		return Result.Err("MissingAISetupComponent", Errors.MISSING_AI_SETUP_COMPONENT, {
			Entity = entity,
			Component = AISharedContract.Components.BehaviorTree,
			Reason = "MissingDefinitionId",
		})
	end

	return Result.Ok({
		BehaviorTree = behaviorTree.value,
		CurrentBehavior = currentBehavior.value,
		BehaviorState = behaviorState.value,
		ActionState = actionState.value,
	})
end

function AIEntityDecisionEvaluator:_ReadRequiredComponent(entity: number, componentKey: string): Result.Result<any>
	local componentResult = self._entityContext:Get(entity, componentKey, AISharedContract.FeatureName)
	if not componentResult.success then
		return Result.Err("MissingAISetupComponent", Errors.MISSING_AI_SETUP_COMPONENT, {
			Entity = entity,
			Component = componentKey,
			CauseType = componentResult.type,
			CauseMessage = componentResult.message,
			Details = componentResult.data,
		})
	end
	if type(componentResult.value) ~= "table" then
		return Result.Err("MissingAISetupComponent", Errors.MISSING_AI_SETUP_COMPONENT, {
			Entity = entity,
			Component = componentKey,
		})
	end

	return componentResult
end

function AIEntityDecisionEvaluator:_CheckTickInterval(
	behaviorTree: any,
	currentBehavior: any,
	options: TAIEntityEvaluationOptions?,
	now: number
): Result.Result<any?>
	if type(options) == "table" and options.Force == true then
		return Result.Ok(nil)
	end

	local tickInterval = if type(behaviorTree.TickInterval) == "number" then behaviorTree.TickInterval else 0
	if tickInterval <= 0 then
		return Result.Ok(nil)
	end

	local lastEvaluatedAt = if type(currentBehavior) == "table" then currentBehavior.LastEvaluatedAt else nil
	if type(lastEvaluatedAt) ~= "number" then
		return Result.Ok(nil)
	end

	local elapsed = now - lastEvaluatedAt
	if elapsed >= tickInterval then
		return Result.Ok(nil)
	end

	return Result.Ok({
		Evaluated = false,
		SkippedReason = "TickInterval",
		DefinitionId = behaviorTree.DefinitionId,
		ActionIntent = nil,
		BehaviorId = self:_ResolveCurrentBehaviorId(currentBehavior),
	})
end

function AIEntityDecisionEvaluator:_BuildEvaluationContext(
	entity: number,
	components: any,
	options: TAIEntityEvaluationOptions?,
	now: number
): any
	local behaviorState = components.BehaviorState
	local blackboard = if type(behaviorState.Blackboard) == "table" then self:_DeepClone(behaviorState.Blackboard) else {}

	return {
		Entity = entity,
		EntityContext = self._entityContext,
		Facts = if type(options) == "table" then self:_DeepClone(options.Facts or {}) else {},
		DeltaTime = if type(options) == "table" and type(options.DeltaTime) == "number" then options.DeltaTime else 0,
		Now = now,
		BehaviorTree = self:_DeepClone(components.BehaviorTree),
		CurrentBehavior = self:_DeepClone(components.CurrentBehavior),
		BehaviorState = self:_DeepClone(components.BehaviorState),
		ActionState = self:_DeepClone(components.ActionState),
		Blackboard = blackboard,
		ActionId = nil,
		ActionIntent = nil,
	}
end

function AIEntityDecisionEvaluator:_RunBehaviorTree(
	compiledTree: any,
	context: any,
	entity: number,
	definitionId: string
): Result.Result<boolean>
	if type(compiledTree) ~= "table" or type(compiledTree.run) ~= "function" then
		return Result.Err("BehaviorTreeExecutionFailed", Errors.BEHAVIOR_TREE_EXECUTION_FAILED, {
			Entity = entity,
			DefinitionId = definitionId,
			Reason = "MissingCompiledTree",
		})
	end

	local didRun, failure = pcall(function()
		compiledTree:run(context)
	end)
	if not didRun then
		return Result.Err("BehaviorTreeExecutionFailed", Errors.BEHAVIOR_TREE_EXECUTION_FAILED, {
			Entity = entity,
			DefinitionId = definitionId,
			Reason = tostring(failure),
		})
	end

	return Result.Ok(true)
end

function AIEntityDecisionEvaluator:_NormalizeActionIntent(entity: number, context: any, now: number): Result.Result<any?>
	local producedActionId = context.ActionId
	local producedIntent = context.ActionIntent
	if producedActionId == nil and producedIntent == nil then
		return Result.Ok(nil)
	end
	if type(producedActionId) ~= "string" or producedActionId == "" then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			Reason = "MissingActionId",
		})
	end
	if producedIntent == nil then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			ActionId = producedActionId,
			Reason = "MissingProducedIntent",
		})
	end
	if type(producedIntent) ~= "table" then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			ActionId = producedActionId,
			Reason = "IntentMustBeTable",
		})
	end

	if producedIntent.ActionId ~= nil and (type(producedIntent.ActionId) ~= "string" or producedIntent.ActionId == "") then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			ActionId = producedActionId,
			Reason = "InvalidIntentActionId",
		})
	end
	if producedIntent.SourceEntity ~= nil and type(producedIntent.SourceEntity) ~= "number" then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			ActionId = producedActionId,
			Reason = "InvalidSourceEntity",
		})
	end
	if producedIntent.TargetEntity ~= nil and type(producedIntent.TargetEntity) ~= "number" then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			ActionId = producedActionId,
			Reason = "InvalidTargetEntity",
		})
	end
	if producedIntent.RequestedAt ~= nil and type(producedIntent.RequestedAt) ~= "number" then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			ActionId = producedActionId,
			Reason = "InvalidRequestedAt",
		})
	end

	local actionId = producedIntent.ActionId or producedActionId
	local sourceEntity = producedIntent.SourceEntity or entity
	local requestedAt = producedIntent.RequestedAt or now
	if actionId ~= producedActionId then
		return Result.Err("InvalidActionIntent", Errors.INVALID_ACTION_INTENT, {
			Entity = entity,
			ActionId = actionId,
			ProducedActionId = producedActionId,
			Reason = "ActionIdMismatch",
		})
	end

	return Result.Ok({
		ActionId = actionId,
		SourceEntity = sourceEntity,
		TargetEntity = producedIntent.TargetEntity,
		Data = self:_DeepClone(producedIntent.Data),
		RequestedAt = requestedAt,
	})
end

function AIEntityDecisionEvaluator:_WriteActionDecision(entity: number, actionIntent: any, now: number): Result.Result<boolean>
	local intentResult =
		self._entityContext:Set(entity, AISharedContract.Components.ActionIntent, actionIntent, AISharedContract.FeatureName)
	if not intentResult.success then
		return intentResult
	end

	local intentTagResult = self._entityContext:Add(entity, AISharedContract.Tags.ActionIntentTag, AISharedContract.FeatureName)
	if not intentTagResult.success then
		return intentTagResult
	end

	local actionDirtyResult = self._entityContext:Add(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
	if not actionDirtyResult.success then
		return actionDirtyResult
	end

	local desiredResult = self._entityContext:Set(entity, AISharedContract.Components.DesiredBehavior, {
		BehaviorId = actionIntent.ActionId,
		NodePath = { actionIntent.ActionId },
		Reason = "Evaluation",
		RequestedAt = now,
	}, AISharedContract.FeatureName)
	if not desiredResult.success then
		return desiredResult
	end

	return self._entityContext:Add(entity, AISharedContract.Tags.BehaviorDirtyTag, AISharedContract.FeatureName)
end

function AIEntityDecisionEvaluator:_ClearActionDecision(
	entity: number,
	currentBehavior: any,
	now: number
): Result.Result<boolean>
	local removeIntentResult =
		self._entityContext:Remove(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	if not removeIntentResult.success then
		return removeIntentResult
	end

	local removeIntentTagResult =
		self._entityContext:Remove(entity, AISharedContract.Tags.ActionIntentTag, AISharedContract.FeatureName)
	if not removeIntentTagResult.success then
		return removeIntentTagResult
	end

	local removeDirtyResult =
		self._entityContext:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
	if not removeDirtyResult.success then
		return removeDirtyResult
	end

	local behaviorId = self:_ResolveCurrentBehaviorId(currentBehavior)
	if behaviorId == nil then
		return Result.Ok(true)
	end

	local desiredResult = self._entityContext:Set(entity, AISharedContract.Components.DesiredBehavior, {
		BehaviorId = behaviorId,
		NodePath = self:_CloneNodePath(currentBehavior.NodePath),
		Reason = "Evaluation",
		RequestedAt = now,
	}, AISharedContract.FeatureName)
	if not desiredResult.success then
		return desiredResult
	end

	return self._entityContext:Add(entity, AISharedContract.Tags.BehaviorDirtyTag, AISharedContract.FeatureName)
end

function AIEntityDecisionEvaluator:_ResolveCurrentBehaviorId(currentBehavior: any): string?
	if type(currentBehavior) ~= "table" then
		return nil
	end
	if type(currentBehavior.BehaviorId) ~= "string" or currentBehavior.BehaviorId == "" then
		return nil
	end

	return currentBehavior.BehaviorId
end

function AIEntityDecisionEvaluator:_CloneNodePath(nodePath: any): { string }
	local clone = {}
	if type(nodePath) ~= "table" then
		return clone
	end

	for _, value in ipairs(nodePath) do
		if type(value) == "string" then
			table.insert(clone, value)
		end
	end
	return clone
end

function AIEntityDecisionEvaluator:_DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_DeepClone(nestedValue)
	end
	return clone
end

return AIEntityDecisionEvaluator
