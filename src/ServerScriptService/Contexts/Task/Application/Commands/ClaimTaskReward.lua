--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local TaskTypes = require(ReplicatedStorage.Contexts.Task.Types.TaskTypes)

local Ok, Try = Result.Ok, Result.Try

type TClaimTaskRewardResult = TaskTypes.TClaimTaskRewardResult
type TTaskRewards = TaskTypes.TTaskRewards

local ClaimTaskReward = {}
ClaimTaskReward.__index = ClaimTaskReward

function ClaimTaskReward.new()
	return setmetatable({}, ClaimTaskReward)
end

function ClaimTaskReward:Init(registry: any, _name: string)
	self._registry = registry
	self.ClaimTaskRewardPolicy = registry:Get("ClaimTaskRewardPolicy")
	self.TaskSyncService = registry:Get("TaskSyncService")
	self.TaskPersistenceService = registry:Get("TaskPersistenceService")
end

function ClaimTaskReward:Start()
	self.ShopContext = self._registry:Get("ShopContext")
	self.InventoryContext = self._registry:Get("InventoryContext")
	self.UnlockContext = self._registry:Get("UnlockContext")
	self.DialogueContext = self._registry:Get("DialogueContext")
	self.EvaluateEligibleTasksService = self._registry:Get("EvaluateEligibleTasksService")
end

function ClaimTaskReward:Execute(player: Player, userId: number, taskId: string): Result.Result<TClaimTaskRewardResult>
	local claimContext = Try(self.ClaimTaskRewardPolicy:Check(userId, taskId))
	local rewards = claimContext.Definition.Rewards

	Try(self:_GrantRewards(player, userId, rewards))

	local claimedProgress = table.clone(claimContext.TaskProgress)
	claimedProgress.Status = "Claimed"
	claimedProgress.ClaimedAt = os.time()
	self.TaskSyncService:UpdateTask(userId, taskId, claimedProgress)

	local state = self.TaskSyncService:GetTaskStateReadOnly(userId)
	if state then
		Try(self.TaskPersistenceService:SaveTaskState(player, state))
		self.TaskSyncService:HydratePlayer(player)
	end

	Try(self.EvaluateEligibleTasksService:Execute(player, userId))

	return Ok({
		TaskId = taskId,
		Status = "Claimed",
		Rewards = rewards,
	})
end

function ClaimTaskReward:_GrantRewards(player: Player, userId: number, rewards: TTaskRewards?): Result.Result<boolean>
	if not rewards then
		return Ok(true)
	end

	if rewards.Gold and rewards.Gold > 0 then
		Try(self.ShopContext:AddGold(player, userId, rewards.Gold))
	end

	if rewards.Items then
		for _, rewardItem in ipairs(rewards.Items) do
			Try(self.InventoryContext:AddItemToInventory(userId, rewardItem.ItemId, rewardItem.Quantity))
		end
	end

	if rewards.Unlocks then
		for _, targetId in ipairs(rewards.Unlocks) do
			Try(self.UnlockContext:GrantUnlock(player, userId, targetId))
		end
	end

	if rewards.Flags then
		for flagName, flagValue in pairs(rewards.Flags) do
			Try(self.DialogueContext:SetDialogueFlag(player, userId, flagName, flagValue))
		end
	end

	return Ok(true)
end

return ClaimTaskReward
