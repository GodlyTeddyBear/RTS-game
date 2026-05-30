--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)
local Result = require(ReplicatedStorage.Utilities.Result)

local AIActionExecutionSystem = {}
AIActionExecutionSystem.__index = AIActionExecutionSystem

function AIActionExecutionSystem.new(entityFactory: any, entityContext: any, actionRegistry: any)
	local self = setmetatable({}, AIActionExecutionSystem)
	self._entityFactory = entityFactory
	self._entityContext = entityContext
	self._actionRegistry = actionRegistry
	return self
end

function AIActionExecutionSystem:Run()
	-- READS: AI.ActionIntent [AUTHORITATIVE], AI.ActionIntentTag, AI.ActionState [AUTHORITATIVE]
	-- WRITES: AI.ActionState [AUTHORITATIVE], AI.ActionDirtyTag, dynamic domain start components [AUTHORITATIVE]
	local queryResult = self._entityFactory:Query({
		FeatureName = AISharedContract.FeatureName,
		Keys = {
			AISharedContract.Components.ActionIntent,
			AISharedContract.Tags.ActionIntentTag,
			AISharedContract.Components.ActionState,
		},
	})
	if not queryResult.success then
		self:_MentionFailure("AI action execution query failed", queryResult)
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function AIActionExecutionSystem:_RunEntity(entity: number, now: number)
	local intentResult = self._entityFactory:Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	if not intentResult.success or type(intentResult.value) ~= "table" then
		return
	end

	local stateResult = self._entityFactory:Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if not stateResult.success or type(stateResult.value) ~= "table" then
		return
	end

	local actionIntent = intentResult.value
	local actionState = stateResult.value
	if actionIntent.SourceEntity ~= entity then
		self:_FailAction(entity, actionState, actionIntent, now, "MismatchedActionSource")
		return
	end

	local actionDefinition = self._actionRegistry:GetActionDefinition(actionIntent.ActionId)
	if actionDefinition == nil then
		self:_FailAction(entity, actionState, actionIntent, now, "UnknownActionDefinition")
		return
	end
	if actionDefinition.StartsComponent == nil or actionDefinition.BuildInitialState == nil then
		return
	end

	local startComponent = actionDefinition.StartsComponent
	local existingStateResult = self._entityFactory:Get(entity, startComponent.Key, startComponent.FeatureName)
	if
		existingStateResult.success
		and type(existingStateResult.value) == "table"
		and existingStateResult.value.ActionId == actionIntent.ActionId
		and existingStateResult.value.RequestedAt == actionIntent.RequestedAt
	then
		return
	end

	local context = {
		Entity = entity,
		EntityContext = self._entityContext,
		ActionIntent = self:_DeepClone(actionIntent),
		ActionState = self:_DeepClone(actionState),
		Now = now,
	}

	local canStartResult = self:_CanStart(actionDefinition, context)
	if not canStartResult.success then
		self:_FailAction(entity, actionState, actionIntent, now, "ActionStartRejected")
		self:_MentionFailure("AI action start rejected", canStartResult)
		return
	end

	local initialStateResult = self:_BuildInitialState(actionDefinition, context)
	if not initialStateResult.success then
		self:_FailAction(entity, actionState, actionIntent, now, "ActionInitialStateBuildFailed")
		self:_MentionFailure("AI action initial state build failed", initialStateResult)
		return
	end

	local setResult = self._entityFactory:Set(entity, startComponent.Key, initialStateResult.value, startComponent.FeatureName)
	if not setResult.success then
		self:_FailAction(entity, actionState, actionIntent, now, "ActionStartComponentWriteFailed")
		self:_MentionFailure("AI action start component write failed", setResult)
		return
	end

	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
end

function AIActionExecutionSystem:_CanStart(actionDefinition: any, context: any): Result.Result<boolean>
	if actionDefinition.CanStart == nil then
		return Result.Ok(true)
	end

	local ok, canStart = pcall(actionDefinition.CanStart, context)
	if not ok then
		return Result.Err("ActionCanStartFailed", "AI:Action CanStart callback failed", {
			ActionId = context.ActionIntent.ActionId,
			Cause = tostring(canStart),
		})
	end
	if Result.isResult(canStart) then
		if not canStart.success then
			return canStart
		end
		if canStart.value == false then
			return Result.Err("ActionStartRejected", "AI:Action start was rejected", {
				ActionId = context.ActionIntent.ActionId,
			})
		end
		return Result.Ok(true)
	end

	if canStart == false then
		return Result.Err("ActionStartRejected", "AI:Action start was rejected", {
			ActionId = context.ActionIntent.ActionId,
		})
	end

	return Result.Ok(true)
end

function AIActionExecutionSystem:_BuildInitialState(actionDefinition: any, context: any): Result.Result<any>
	local ok, initialState = pcall(actionDefinition.BuildInitialState, context)
	if not ok then
		return Result.Err("ActionInitialStateBuildFailed", "AI:Action initial state build failed", {
			ActionId = context.ActionIntent.ActionId,
			Cause = tostring(initialState),
		})
	end
	if Result.isResult(initialState) then
		if not initialState.success then
			return initialState
		end
		initialState = initialState.value
	end
	if type(initialState) ~= "table" then
		return Result.Err("InvalidActionInitialState", "AI:Action initial state must be a table", {
			ActionId = context.ActionIntent.ActionId,
		})
	end

	local normalized = self:_DeepClone(initialState)
	normalized.ActionId = normalized.ActionId or context.ActionIntent.ActionId
	normalized.SourceEntity = normalized.SourceEntity or context.Entity
	normalized.TargetEntity = if normalized.TargetEntity ~= nil then normalized.TargetEntity else context.ActionIntent.TargetEntity
	normalized.RequestedAt = normalized.RequestedAt or context.ActionIntent.RequestedAt
	normalized.StartedAt = normalized.StartedAt or context.Now
	normalized.Status = normalized.Status or "Started"

	return Result.Ok(normalized)
end

function AIActionExecutionSystem:_FailAction(entity: number, actionState: any, actionIntent: any, now: number, errorCode: string)
	self._entityFactory:Set(entity, AISharedContract.Components.ActionState, {
		ActionId = if type(actionIntent) == "table" then actionIntent.ActionId else actionState.ActionId,
		Status = AISharedContract.ActionStatus.Failed,
		StartedAt = actionState.StartedAt,
		UpdatedAt = now,
		ErrorCode = errorCode,
	}, AISharedContract.FeatureName)
	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
end

function AIActionExecutionSystem:_DeepClone(value: any): any
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, nestedValue in pairs(value) do
		clone[key] = self:_DeepClone(nestedValue)
	end
	return clone
end

function AIActionExecutionSystem:_MentionFailure(message: string, result: Result.Result<any>)
	Result.MentionError("AIActionExecutionSystem:Run", message, {
		CauseType = result.type,
		CauseMessage = result.message,
		Details = result.data,
	}, result.type)
end

return AIActionExecutionSystem
