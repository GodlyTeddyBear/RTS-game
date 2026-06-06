--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local MovementActionCompletionSystem = {}
MovementActionCompletionSystem.__index = MovementActionCompletionSystem

local ACTION_MANUAL_MOVE = "ManualMove"

function MovementActionCompletionSystem.new(entityFactory: any)
	return setmetatable({ _entityFactory = entityFactory }, MovementActionCompletionSystem)
end

function MovementActionCompletionSystem:Run()
	-- READS: Movement.CompletedIntent [DERIVED], AI.ActionState [AUTHORITATIVE], Unit.PathState [AUTHORITATIVE]
	-- WRITES: AI.ActionState [AUTHORITATIVE], AI.ActionIntent [AUTHORITATIVE], AI.ActionIntentTag, Unit.PathState [AUTHORITATIVE], Entity.DirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = "Movement",
		Keys = { "CompletedIntent" },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		self:_RunEntity(entity, now)
	end
end

function MovementActionCompletionSystem:_RunEntity(entity: number, now: number)
	local completedIntent = self:_Get(entity, "CompletedIntent", "Movement")
	if type(completedIntent) ~= "table" then
		return
	end

	self:_CompleteMatchingAction(entity, completedIntent, now)
	if completedIntent.ActionId == ACTION_MANUAL_MOVE then
		self:_CompleteUnitManualMove(entity)
	end
end

function MovementActionCompletionSystem:_CompleteMatchingAction(entity: number, completedIntent: any, now: number)
	local actionState = self:_Get(entity, AISharedContract.Components.ActionState, AISharedContract.FeatureName)
	if type(actionState) ~= "table" or actionState.ActionId ~= completedIntent.ActionId then
		return
	end

	self._entityFactory:Set(entity, AISharedContract.Components.ActionState, {
		ActionId = actionState.ActionId,
		Status = AISharedContract.ActionStatus.Completed,
		StartedAt = actionState.StartedAt,
		UpdatedAt = now,
		ErrorCode = nil,
	}, AISharedContract.FeatureName)
	self._entityFactory:Remove(entity, AISharedContract.Components.ActionIntent, AISharedContract.FeatureName)
	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionIntentTag, AISharedContract.FeatureName)
	self._entityFactory:Remove(entity, AISharedContract.Tags.ActionDirtyTag, AISharedContract.FeatureName)
end

function MovementActionCompletionSystem:_CompleteUnitManualMove(entity: number)
	local pathState = self:_Get(entity, "PathState", "Unit")
	if type(pathState) ~= "table" then
		return
	end

	self._entityFactory:Set(entity, "PathState", {
		GoalPosition = nil,
		RequestedGoalPosition = pathState.RequestedGoalPosition,
		GoalRevision = pathState.GoalRevision,
		FailedGoalRevision = pathState.FailedGoalRevision,
		IsMoving = false,
	}, "Unit")
	self._entityFactory:Add(entity, "DirtyTag", "Entity")
end

function MovementActionCompletionSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementActionCompletionSystem
