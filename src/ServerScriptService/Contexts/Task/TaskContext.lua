--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.TaskSyncServer)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try
local Events = GameEvents.Events

local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

local TaskProgressCalculator = require(script.Parent.TaskDomain.Services.TaskProgressCalculator)
local TaskEligibilityPolicy = require(script.Parent.TaskDomain.Policies.TaskEligibilityPolicy)
local ClaimTaskRewardPolicy = require(script.Parent.TaskDomain.Policies.ClaimTaskRewardPolicy)

local TaskSyncService = require(script.Parent.Infrastructure.Persistence.TaskSyncService)
local TaskPersistenceService = require(script.Parent.Infrastructure.Persistence.TaskPersistenceService)

local EvaluateEligibleTasks = require(script.Parent.Application.Commands.EvaluateEligibleTasks)
local ProcessTaskProgress = require(script.Parent.Application.Commands.ProcessTaskProgress)
local ClaimTaskReward = require(script.Parent.Application.Commands.ClaimTaskReward)
local GetTaskState = require(script.Parent.Application.Queries.GetTaskState)

local TaskContext = Knit.CreateService({
	Name = "TaskContext",
	Client = {},
})

function TaskContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	registry:Register("ProfileManager", ProfileManager)
	registry:Register("BlinkServer", BlinkServer)

	PlayerLifecycleManager:RegisterLoader("TaskContext")

	registry:Register("TaskProgressCalculator", TaskProgressCalculator.new(), "Domain")
	registry:Register("TaskEligibilityPolicy", TaskEligibilityPolicy.new(), "Domain")
	registry:Register("ClaimTaskRewardPolicy", ClaimTaskRewardPolicy.new(), "Domain")

	registry:Register("TaskSyncService", TaskSyncService.new(), "Infrastructure")
	registry:Register("TaskPersistenceService", TaskPersistenceService.new(), "Infrastructure")

	registry:Register("EvaluateEligibleTasksService", EvaluateEligibleTasks.new(), "Application")
	registry:Register("ProcessTaskProgressService", ProcessTaskProgress.new(), "Application")
	registry:Register("ClaimTaskRewardService", ClaimTaskReward.new(), "Application")
	registry:Register("GetTaskStateQuery", GetTaskState.new(), "Application")

	registry:InitAll()

	self.TaskSyncService = registry:Get("TaskSyncService")
	self.TaskPersistenceService = registry:Get("TaskPersistenceService")
	self.EvaluateEligibleTasksService = registry:Get("EvaluateEligibleTasksService")
	self.ProcessTaskProgressService = registry:Get("ProcessTaskProgressService")
	self.ClaimTaskRewardService = registry:Get("ClaimTaskRewardService")
	self.GetTaskStateQuery = registry:Get("GetTaskStateQuery")
end

function TaskContext:KnitStart()
	self.Registry:Register("ShopContext", Knit.GetService("ShopContext"))
	self.Registry:Register("InventoryContext", Knit.GetService("InventoryContext"))
	self.Registry:Register("UnlockContext", Knit.GetService("UnlockContext"))
	self.Registry:Register("QuestContext", Knit.GetService("QuestContext"))
	self.Registry:Register("DialogueContext", Knit.GetService("DialogueContext"))

	self.Registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	self:_ConnectLifecycleEvents()
	self:_ConnectProgressEvents()
	self:_ConnectEligibilityEvents()
end

function TaskContext:_ConnectLifecycleEvents()
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadTaskStateOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "TaskContext")
			end)
			:catch(function(err)
				warn("[TaskContext] Failed to load player data:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		Catch(function()
			self:_CleanupOnPlayerLeave(player)
			return Ok(nil)
		end, "TaskContext:ProfileSaving")
	end)
end

function TaskContext:_ConnectProgressEvents()
	GameEvents.Bus:On(Events.Crafting.CraftingCompleted, function(userId: number, _recipeId: string, resultItemId: string, quantity: number)
		self:_ProcessTrustedProgress(userId, {
			UserId = userId,
			Kind = "CraftItem",
			TargetId = resultItemId,
			Amount = quantity,
		})
	end)

	GameEvents.Bus:On(Events.Combat.NPCDied, function(userId: number, npcId: string, npcType: string, team: string)
		if team ~= "Enemy" then
			return
		end

		if npcType ~= "" then
			self:_ProcessTrustedProgress(userId, {
				UserId = userId,
				Kind = "KillNPC",
				TargetId = npcType,
				Amount = 1,
			})
		end

		if npcId ~= npcType then
			self:_ProcessTrustedProgress(userId, {
				UserId = userId,
				Kind = "KillNPC",
				TargetId = npcId,
				Amount = 1,
			})
		end
	end)
end

function TaskContext:_ConnectEligibilityEvents()
	GameEvents.Bus:On(Events.Persistence.PlayerReady, function(player)
		self:_EvaluateEligibleTasksForPlayer(player)
	end)

	GameEvents.Bus:On(Events.Quest.QuestCompleted, function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self:_EvaluateEligibleTasksForPlayer(player)
		end
	end)

	GameEvents.Bus:On(Events.Chapter.ChapterAdvanced, function(userId: number, _newChapter: number)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self:_EvaluateEligibleTasksForPlayer(player)
		end
	end)

	GameEvents.Bus:On(Events.Dialogue.FlagSet, function(userId: number, _flagName: string)
		local player = Players:GetPlayerByUserId(userId)
		if player then
			self:_EvaluateEligibleTasksForPlayer(player)
		end
	end)
end

function TaskContext:_LoadTaskStateOnPlayerJoin(player: Player)
	local userId = player.UserId
	local state = self.TaskPersistenceService:LoadTaskState(player)
	self.TaskSyncService:LoadUserTasks(userId, state)
	self.EvaluateEligibleTasksService:Execute(player, userId)
	self.TaskSyncService:HydratePlayer(player)
end

function TaskContext:_CleanupOnPlayerLeave(player: Player)
	local userId = player.UserId
	local state = self.TaskSyncService:GetTaskStateReadOnly(userId)
	if state then
		Try(self.TaskPersistenceService:SaveTaskState(player, state))
	end
	self.TaskSyncService:RemoveUserTasks(userId)
end

function TaskContext:_ProcessTrustedProgress(userId: number, input: any)
	local player = Players:GetPlayerByUserId(userId)
	if not player then
		return
	end

	Catch(function()
		Try(self.ProcessTaskProgressService:Execute(player, input))
		return Ok(nil)
	end, "Task:ProcessTrustedProgress")
end

function TaskContext:_EvaluateEligibleTasksForPlayer(player: Player)
	if not self.TaskSyncService:IsPlayerLoaded(player.UserId) then
		return
	end

	Catch(function()
		Try(self.EvaluateEligibleTasksService:Execute(player, player.UserId))
		return Ok(nil)
	end, "Task:EvaluateEligibleTasksForPlayer")
end

function TaskContext:_EnsureTaskStateLoaded(player: Player)
	local userId = player.UserId
	if self.TaskSyncService:IsPlayerLoaded(userId) then
		return
	end

	if not PlayerLifecycleManager:IsPlayerReady(player) then
		GameEvents.Bus:Wait(Events.Persistence.PlayerReady)
	end

	local state = self.TaskPersistenceService:LoadTaskState(player)
	self.TaskSyncService:LoadUserTasks(userId, state)
	Try(self.EvaluateEligibleTasksService:Execute(player, userId))
end

function TaskContext:RequestTaskState(player: Player): Result.Result<boolean>
	return Catch(function()
		self:_EnsureTaskStateLoaded(player)
		self.TaskSyncService:HydratePlayer(player)
		return Ok(true)
	end, "Task:RequestTaskState")
end

function TaskContext:ClaimTaskReward(player: Player, taskId: string): Result.Result<any>
	local userId = player.UserId
	return Catch(function()
		return self.ClaimTaskRewardService:Execute(player, userId, taskId)
	end, "Task:ClaimTaskReward")
end

function TaskContext:GetTaskState(userId: number): Result.Result<any>
	return Catch(function()
		return self.GetTaskStateQuery:Execute(userId)
	end, "Task:GetTaskState")
end

function TaskContext.Client:RequestTaskState(player: Player)
	return self.Server:RequestTaskState(player)
end

function TaskContext.Client:ClaimTaskReward(player: Player, taskId: string)
	return self.Server:ClaimTaskReward(player, taskId)
end

WrapContext(TaskContext, "TaskContext")

return TaskContext
