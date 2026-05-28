--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AISharedContract = require(ReplicatedStorage.Contexts.AI.AISharedContract)

local AIBehaviorCommitSystem = {}
AIBehaviorCommitSystem.__index = AIBehaviorCommitSystem

local function _CloneArray(source: any): { string }
	if type(source) ~= "table" then
		return {}
	end

	local clone = {}
	for _, value in ipairs(source) do
		if type(value) == "string" then
			table.insert(clone, value)
		end
	end
	return clone
end

local function _IsValidDesiredBehavior(desiredBehavior: any): boolean
	return type(desiredBehavior) == "table"
		and type(desiredBehavior.BehaviorId) == "string"
		and desiredBehavior.BehaviorId ~= ""
end

function AIBehaviorCommitSystem.new(entityFactory: any)
	local self = setmetatable({}, AIBehaviorCommitSystem)
	self._entityFactory = entityFactory
	return self
end

function AIBehaviorCommitSystem:Run()
	-- READS: AI.DesiredBehavior [AUTHORITATIVE], AI.BehaviorState [AUTHORITATIVE]
	-- WRITES: AI.CurrentBehavior [AUTHORITATIVE], AI.BehaviorState [AUTHORITATIVE], AI.BehaviorDirtyTag
	local queryResult = self._entityFactory:Query({
		FeatureName = AISharedContract.FeatureName,
		Keys = { AISharedContract.Components.DesiredBehavior },
	})
	if not queryResult.success then
		return
	end

	for _, entity in ipairs(queryResult.value) do
		self:_CommitEntityBehavior(entity)
	end
end

function AIBehaviorCommitSystem:_CommitEntityBehavior(entity: number)
	local desiredResult =
		self._entityFactory:Get(entity, AISharedContract.Components.DesiredBehavior, AISharedContract.FeatureName)
	if not desiredResult.success or not _IsValidDesiredBehavior(desiredResult.value) then
		self._entityFactory:Remove(entity, AISharedContract.Tags.BehaviorDirtyTag, AISharedContract.FeatureName)
		return
	end

	local desiredBehavior = desiredResult.value
	local transitionTimestamp = if type(desiredBehavior.RequestedAt) == "number" then desiredBehavior.RequestedAt else os.clock()

	local currentResult =
		self._entityFactory:Get(entity, AISharedContract.Components.CurrentBehavior, AISharedContract.FeatureName)
	local currentBehavior = if currentResult.success and type(currentResult.value) == "table" then currentResult.value else nil
	local isSameBehavior = currentBehavior ~= nil and currentBehavior.BehaviorId == desiredBehavior.BehaviorId

	local behaviorState = self:_BuildNextBehaviorState(entity, isSameBehavior)
	local stateResult =
		self._entityFactory:Set(entity, AISharedContract.Components.BehaviorState, behaviorState, AISharedContract.FeatureName)
	if not stateResult.success then
		return
	end

	local commitResult = self._entityFactory:Set(entity, AISharedContract.Components.CurrentBehavior, {
		BehaviorId = desiredBehavior.BehaviorId,
		NodePath = _CloneArray(desiredBehavior.NodePath),
		Status = AISharedContract.BehaviorStatus.Active,
		EnteredAt = if isSameBehavior and currentBehavior ~= nil then currentBehavior.EnteredAt else transitionTimestamp,
		LastEvaluatedAt = transitionTimestamp,
	}, AISharedContract.FeatureName)
	if not commitResult.success then
		return
	end

	self._entityFactory:Remove(entity, AISharedContract.Tags.BehaviorDirtyTag, AISharedContract.FeatureName)
end

function AIBehaviorCommitSystem:_BuildNextBehaviorState(entity: number, isSameBehavior: boolean): any
	local stateResult =
		self._entityFactory:Get(entity, AISharedContract.Components.BehaviorState, AISharedContract.FeatureName)
	local currentState = if stateResult.success and type(stateResult.value) == "table" then stateResult.value else {}
	local transitionCount = if type(currentState.TransitionCount) == "number" then currentState.TransitionCount else 0

	return {
		Blackboard = if type(currentState.Blackboard) == "table" then table.clone(currentState.Blackboard) else {},
		TransitionCount = if isSameBehavior then transitionCount else transitionCount + 1,
	}
end

return AIBehaviorCommitSystem
