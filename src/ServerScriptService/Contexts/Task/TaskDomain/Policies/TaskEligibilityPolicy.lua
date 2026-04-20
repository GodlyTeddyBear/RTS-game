--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local TaskConfig = require(ReplicatedStorage.Contexts.Task.Config.TaskConfig)
local TaskSpecs = require(script.Parent.Parent.Specs.TaskSpecs)

local Ok = Result.Ok

local TaskEligibilityPolicy = {}
TaskEligibilityPolicy.__index = TaskEligibilityPolicy

function TaskEligibilityPolicy.new()
	return setmetatable({}, TaskEligibilityPolicy)
end

function TaskEligibilityPolicy:Init(registry: any, _name: string)
	self.TaskSyncService = registry:Get("TaskSyncService")
	self.ProfileManager = registry:Get("ProfileManager")
	self._registry = registry
end

function TaskEligibilityPolicy:Start()
	self.UnlockContext = self._registry:Get("UnlockContext")
	self.QuestContext = self._registry:Get("QuestContext")
	self.DialogueContext = self._registry:Get("DialogueContext")
end

function TaskEligibilityPolicy:CollectEligibleTaskIds(player: Player, userId: number): Result.Result<{ string }>
	local state = self.TaskSyncService:GetTaskStateReadOnly(userId)
	if not state then
		return Ok({})
	end

	local candidateBase = self:_BuildCandidateBase(player, userId, state)
	local eligibleTaskIds = {}

	for taskId, definition in pairs(TaskConfig) do
		if self:_CanConsiderTask(state, taskId, definition) then
			local candidate = table.clone(candidateBase)
			candidate.Conditions = definition.UnlockConditions
			if TaskSpecs.CanStartTask:IsSatisfiedBy(candidate).success then
				table.insert(eligibleTaskIds, taskId)
			end
		end
	end

	table.sort(eligibleTaskIds)
	return Ok(eligibleTaskIds)
end

function TaskEligibilityPolicy:_BuildCandidateBase(player: Player, userId: number, state: any): TaskSpecs.TTaskEligibilityCandidate
	local profileData = self.ProfileManager:GetData(player) or {}
	return {
		Chapter = profileData.Chapter or 1,
		UnlockedTargets = self:_BuildUnlockLookup(userId),
		ClaimedTaskIds = self:_BuildClaimedTaskLookup(state),
		ExpeditionsCompleted = self:_GetExpeditionsCompleted(userId),
		Flags = self:_GetFlags(player, userId),
		Conditions = nil,
	}
end

function TaskEligibilityPolicy:_CanConsiderTask(state: any, taskId: string, definition: any): boolean
	local existingTask = state.Tasks[taskId]
	if not existingTask then
		return true
	end

	return definition.Repeatable == true and existingTask.Status == "Claimed"
end

function TaskEligibilityPolicy:_BuildUnlockLookup(userId: number): { [string]: boolean }
	local result = self.UnlockContext:GetUnlockState(userId)
	if not result.success then
		return {}
	end
	return result.value.unlocks or result.value or {}
end

function TaskEligibilityPolicy:_BuildClaimedTaskLookup(state: any): { [string]: boolean }
	local claimedTaskIds = {}
	for taskId, taskProgress in pairs(state.Tasks) do
		claimedTaskIds[taskId] = taskProgress.Status == "Claimed"
	end
	return claimedTaskIds
end

function TaskEligibilityPolicy:_GetExpeditionsCompleted(userId: number): number
	local result = self.QuestContext:GetQuestStateForUser(userId)
	if not result.success then
		return 0
	end
	return result.value.CompletedCount or 0
end

function TaskEligibilityPolicy:_GetFlags(player: Player, userId: number): { [string]: any }
	local result = self.DialogueContext:GetPlayerDialogueFlags(player)
	if result.success then
		return result.value
	end

	local flags = {}
	local profileData = self.ProfileManager:GetData(player)
	if profileData and profileData.Flags then
		for flagName, flagValue in pairs(profileData.Flags) do
			flags[flagName] = flagValue
		end
	end
	return flags
end

return TaskEligibilityPolicy
