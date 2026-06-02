--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local AIActionLifecycleSystem = {}
AIActionLifecycleSystem.__index = AIActionLifecycleSystem

local function _IsRunning(status: any): boolean
	return status == AISharedContract.ActionStatus.Requested or status == AISharedContract.ActionStatus.Running
end

function AIActionLifecycleSystem.new(entityFactory: any)
	local self = setmetatable({}, AIActionLifecycleSystem)
	self._entityFactory = entityFactory
	return self
end

function AIActionLifecycleSystem:Run()
	-- READS: AI.ActionIntent [AUTHORITATIVE], AI.ActionIntentTag, AI.ActionState [AUTHORITATIVE]
	-- WRITES: AI.ActionState [AUTHORITATIVE], AI.ActionIntentTag, AI.ActionDirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = AISharedContract.FeatureName,
		Keys = { AISharedContract.Components.ActionState },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntityLifecycle(entity, now)
	end
end

function AIActionLifecycleSystem:_RunEntityLifecycle(entity: number, now: number)
	local stateResult = self._entityFactory:Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if not stateResult.success or type(stateResult.value) ~= "table" then
		return
	end

	local actionState = stateResult.value
	local intentTagged = self:_HasTag(entity, AISharedContract.Tags.ActionIntentTag)
	local intentResult = self._entityFactory:Get(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	local actionIntent = if intentResult.success then intentResult.value else nil

	if type(actionIntent) == "table" and not self:_IsValidIntent(actionIntent) then
		self:_FailAction(entity, actionState, actionIntent, now, "InvalidActionIntent")
		return
	end

	if not intentTagged or type(actionIntent) ~= "table" then
		self:_CancelIfRunning(entity, actionState, now)
		return
	end

	self:_StartOrRefreshAction(entity, actionState, actionIntent, now)
end

function AIActionLifecycleSystem:_StartOrRefreshAction(entity: number, actionState: any, actionIntent: any, now: number)
	local currentActionId = if type(actionState.ActionId) == "string" and actionState.ActionId ~= ""
		then actionState.ActionId
		else nil
	local isSameRunningAction = currentActionId == actionIntent.ActionId and _IsRunning(actionState.Status)
	local startedAt = if isSameRunningAction and type(actionState.StartedAt) == "number" then actionState.StartedAt else now

	local setResult = self._entityFactory:Set(entity, AISharedContract.Components.ActionState, {
		ActionId = actionIntent.ActionId,
		Status = AISharedContract.ActionStatus.Running,
		StartedAt = startedAt,
		UpdatedAt = now,
		ErrorCode = nil,
	}, AISharedContract.FeatureName)
	if not setResult.success then
		return
	end

	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
end

function AIActionLifecycleSystem:_CancelIfRunning(entity: number, actionState: any, now: number)
	if not _IsRunning(actionState.Status) then
		return
	end

	self._entityFactory:Set(entity, AISharedContract.Components.ActionState, {
		ActionId = actionState.ActionId,
		Status = AISharedContract.ActionStatus.Cancelled,
		StartedAt = actionState.StartedAt,
		UpdatedAt = now,
		ErrorCode = nil,
	}, AISharedContract.FeatureName)
	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
end

function AIActionLifecycleSystem:_FailAction(
	entity: number,
	actionState: any,
	actionIntent: any,
	now: number,
	errorCode: string
)
	local actionId = if type(actionIntent) == "table" and type(actionIntent.ActionId) == "string" and actionIntent.ActionId ~= ""
		then actionIntent.ActionId
		else actionState.ActionId

	self._entityFactory:Set(entity, AISharedContract.Components.ActionState, {
		ActionId = actionId,
		Status = AISharedContract.ActionStatus.Failed,
		StartedAt = actionState.StartedAt,
		UpdatedAt = now,
		ErrorCode = errorCode,
	}, AISharedContract.FeatureName)
	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionIntentTag, AISharedContract.FeatureName)
	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
end

function AIActionLifecycleSystem:_IsValidIntent(actionIntent: any): boolean
	if type(actionIntent.ActionId) ~= "string" or actionIntent.ActionId == "" then
		return false
	end
	if type(actionIntent.SourceEntity) ~= "number" or not self._entityFactory:Exists(actionIntent.SourceEntity) then
		return false
	end
	if
		actionIntent.TargetEntity ~= nil
		and (type(actionIntent.TargetEntity) ~= "number" or not self._entityFactory:Exists(actionIntent.TargetEntity))
	then
		return false
	end

	return true
end

function AIActionLifecycleSystem:_HasTag(entity: number, tagKey: string): boolean
	local tagResult = self._entityFactory:Has(entity, AISharedContract.FeatureName, tagKey)
	return tagResult.success and tagResult.value == true
end

return AIActionLifecycleSystem
