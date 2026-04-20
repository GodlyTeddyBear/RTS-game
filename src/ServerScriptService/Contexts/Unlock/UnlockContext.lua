--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.UnlockSyncServer)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local ChapterConfig = require(ReplicatedStorage.Contexts.Unlock.Config.ChapterConfig)

local Catch = Result.Catch
local Ok = Result.Ok
local Events = GameEvents.Events

-- Data access
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

-- Domain
local UnlockConditionResolver = require(script.Parent.UnlockDomain.Services.UnlockConditionResolver)
local UnlockConditionEvaluator = require(script.Parent.UnlockDomain.Services.UnlockConditionEvaluator)
local PurchaseUnlockPolicy = require(script.Parent.UnlockDomain.Policies.PurchaseUnlockPolicy)

-- Infrastructure
local UnlockSyncService = require(script.Parent.Infrastructure.Persistence.UnlockSyncService)
local UnlockPersistenceService = require(script.Parent.Infrastructure.Persistence.UnlockPersistenceService)

-- Application
local EvaluateAllUnlocks = require(script.Parent.Application.Commands.EvaluateAllUnlocks)
local ProcessAutoUnlocks = require(script.Parent.Application.Commands.ProcessAutoUnlocks)
local EvaluateChapterAdvancement = require(script.Parent.Application.Commands.EvaluateChapterAdvancement)
local PurchaseUnlock = require(script.Parent.Application.Commands.PurchaseUnlock)
local GetUnlockState = require(script.Parent.Application.Queries.GetUnlockState)

--[=[
	@class UnlockContext
	Knit service for the Unlock bounded context.

	Manages player unlock state: auto-unlocks triggered by game events,
	player-initiated purchases, and on-demand state hydration to the client.
	@server
]=]
local UnlockContext = Knit.CreateService({
	Name = "UnlockContext",
	Client = {},
})

---
-- Knit Lifecycle
---

--[=[
	@within UnlockContext
	@private
]=]
function UnlockContext:KnitInit()
	-- Register dependencies and initialize services
	local registry = Registry.new("Server")

	-- Raw values
	registry:Register("ProfileManager", ProfileManager)
	registry:Register("BlinkServer", BlinkServer)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("UnlockContext")

	-- Domain
	registry:Register("UnlockConditionResolver", UnlockConditionResolver.new(), "Domain")
	registry:Register("UnlockConditionEvaluator", UnlockConditionEvaluator.new(), "Domain")
	registry:Register("PurchaseUnlockPolicy", PurchaseUnlockPolicy.new(), "Domain")

	-- Infrastructure
	registry:Register("UnlockSyncService", UnlockSyncService.new(), "Infrastructure")
	registry:Register("UnlockPersistenceService", UnlockPersistenceService.new(), "Infrastructure")

	-- Application
	registry:Register("EvaluateAllUnlocksService", EvaluateAllUnlocks.new(), "Application")
	registry:Register("ProcessAutoUnlocksService", ProcessAutoUnlocks.new(), "Application")
	registry:Register("EvaluateChapterAdvancementService", EvaluateChapterAdvancement.new(), "Application")
	registry:Register("PurchaseUnlockService", PurchaseUnlock.new(), "Application")
	registry:Register("GetUnlockStateQuery", GetUnlockState.new(), "Application")

	registry:InitAll()

	-- Cache local refs to avoid registry lookups during execution
	self.UnlockSyncService = registry:Get("UnlockSyncService")
	self.UnlockPersistenceService = registry:Get("UnlockPersistenceService")
	self.EvaluateAllUnlocksService = registry:Get("EvaluateAllUnlocksService")
	self.ProcessAutoUnlocksService = registry:Get("ProcessAutoUnlocksService")
	self.EvaluateChapterAdvancementService = registry:Get("EvaluateChapterAdvancementService")
	self.PurchaseUnlockService = registry:Get("PurchaseUnlockService")
	self.GetUnlockStateQuery = registry:Get("GetUnlockStateQuery")

	self._registry = registry
end

--[=[
	@within UnlockContext
	@private
]=]
function UnlockContext:KnitStart()
	-- Wire cross-context dependencies needed by domain/infrastructure services
	self._registry:Register("CommissionContext", Knit.GetService("CommissionContext"))
	self._registry:Register("QuestContext", Knit.GetService("QuestContext"))
	self._registry:Register("ShopContext", Knit.GetService("ShopContext"))
	self._registry:Register("WorkerContext", Knit.GetService("WorkerContext"))
	self._registry:Register("DialogueContext", Knit.GetService("DialogueContext"))
	self._registry:Register("UpgradeContext", Knit.GetService("UpgradeContext"))

	self._registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Load unlock atom when profile becomes available
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadUnlockAtom(player)
				PlayerLifecycleManager:NotifyLoaded(player, "UnlockContext")
			end)
			:catch(function(err)
				warn("[UnlockContext] Failed to load player data:", tostring(err))
			end)
	end)

	-- Evaluate all unlocks once all contexts ready (prevents cross-context read failures)
	GameEvents.Bus:On(Events.Persistence.PlayerReady, function(player)
		local userId = player.UserId
		task.spawn(function()
			self.EvaluateAllUnlocksService:Execute(player, userId)
			self.EvaluateChapterAdvancementService:Execute(player, userId)
			self:_EmitMissingChapterIntro(player, userId)
			self.UnlockSyncService:HydratePlayer(player)
		end)
	end)

	-- Cleanup unlock state when player profile saves
	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		Catch(function()
			self:_CleanupOnPlayerLeave(player)
			return Ok(nil)
		end, "UnlockContext:ProfileSaving", function(err)
			warn("[UnlockContext] ProfileSaving error:", err.type, err.message)
		end)
	end)

	-- React to condition changes that may trigger auto-unlocks or chapter advancement
	GameEvents.Bus:On(Events.Commission.CommissionTierUnlocked, function(userId: number, _newTier: number)
		self:_DispatchAutoUnlockTrigger(userId, "CommissionTier")
		self:_DispatchChapterEvaluation(userId)
	end)

	GameEvents.Bus:On(Events.Quest.QuestCompleted, function(userId: number)
		self:_DispatchAutoUnlockTrigger(userId, "QuestsCompleted")
		self:_DispatchChapterEvaluation(userId)
	end)

	GameEvents.Bus:On(Events.Worker.WorkerHired, function(userId: number, _workerId: string, _workerType: string)
		self:_DispatchAutoUnlockTrigger(userId, "WorkerCount")
		self:_DispatchChapterEvaluation(userId)
	end)

	GameEvents.Bus:On(Events.Dialogue.FlagSet, function(userId: number, flagName: string)
		if flagName == "Ch1_SmelterPlaced" or flagName == "Ch2_FirstVictory" then
			self:_DispatchChapterEvaluation(userId)
		end
	end)

	-- When chapter advances, re-evaluate auto-unlocks filtered to Chapter condition
	GameEvents.Bus:On(Events.Chapter.ChapterAdvanced, function(userId: number, _newChapter: number)
		self:_DispatchAutoUnlockTrigger(userId, "Chapter")
	end)

end

---
-- Player Data Loading
---

--[=[
	@within UnlockContext
	@private
]=]
function UnlockContext:_LoadUnlockAtom(player: Player)
	local userId = player.UserId
	local state = self.UnlockPersistenceService:LoadUnlockData(player) or {}
	self.UnlockSyncService:LoadUserUnlocks(userId, state)
end

--[=[
	@within UnlockContext
	@private
]=]
function UnlockContext:_CleanupOnPlayerLeave(player: Player)
	local userId = player.UserId
	local state = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	if state then
		self.UnlockPersistenceService:SaveUnlockData(player, state)
	end
	self.UnlockSyncService:RemoveUserUnlocks(userId)
end

---
-- Helpers
---

--- Dispatches chapter advancement check if player is loaded
function UnlockContext:_DispatchChapterEvaluation(userId: number)
	local player = self:_GetPlayerByUserId(userId)
	-- Guard against race where player leaves before state loads
	if player and self.UnlockSyncService:IsPlayerLoaded(userId) then
		task.spawn(function()
			self.EvaluateChapterAdvancementService:Execute(player, userId)
		end)
	end
end

--- Dispatches trigger-based auto-unlock evaluation if player is loaded
function UnlockContext:_DispatchAutoUnlockTrigger(userId: number, triggerField: string)
	local player = self:_GetPlayerByUserId(userId)
	-- Guard against race where player leaves before state loads
	if player and self.UnlockSyncService:IsPlayerLoaded(userId) then
		task.spawn(function()
			self.ProcessAutoUnlocksService:Execute(player, userId, triggerField)
		end)
	end
end

--- Ensures unlock state is loaded from persistence if missing.
function UnlockContext:_EnsureUnlocksLoaded(player: Player, userId: number)
	if self.UnlockSyncService:IsPlayerLoaded(userId) then return end

	-- Load from persistence or initialize empty
	local savedData = self.UnlockPersistenceService:LoadUnlockData(player)
	self.UnlockSyncService:LoadUserUnlocks(userId, savedData or {})
end

--- Emits a chapter's IntroEvent if the player is on that chapter but has not yet seen the intro.
--- Handles retroactive players who advanced before the intro event existed.
function UnlockContext:_EmitMissingChapterIntro(player: Player, userId: number)
	local data = ProfileManager:GetData(player)
	if not data then return end

	local currentChapter = data.Chapter or 1
	local entry = ChapterConfig[currentChapter]
	if not entry or not entry.IntroEvent or not entry.IntroSeenFlag then return end

	local dialogueContext = self._registry:Get("DialogueContext")
	local alreadySeen = dialogueContext:GetDialogueFlag(userId, entry.IntroSeenFlag) == true
	if alreadySeen then return end

	GameEvents.Bus:Emit(entry.IntroEvent, userId)
end

--[=[
	@within UnlockContext
	@private
]=]
function UnlockContext:_GetPlayerByUserId(userId: number): Player?
	return Players:GetPlayerByUserId(userId)
end

---
-- Server-to-Server API
---

--[=[
	Fast boolean check: is this target unlocked for this player?
	`StartsUnlocked` items and unknown targets always return `true`.
	@within UnlockContext
	@param userId number -- The player's user ID
	@param targetId string -- The unlock target to check
	@return boolean
]=]
function UnlockContext:IsUnlocked(userId: number, targetId: string): boolean
	local entry = UnlockConfig[targetId]
	if not entry or entry.StartsUnlocked then
		return true
	end
	local state = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
	if not state then
		return false
	end
	return state[targetId] == true
end

--[=[
	Returns the player's current chapter number.
	@within UnlockContext
	@param player Player -- The player to query
	@return number
]=]
function UnlockContext:GetCurrentChapter(player: Player): number
	local data = ProfileManager:GetData(player)
	return if data and data.Chapter then data.Chapter else 1
end

--[=[
	Initiates a player-purchased unlock for the given target.
	@within UnlockContext
	@param player Player -- The purchasing player
	@param targetId string -- The unlock target to purchase
	@return Result.Result<boolean>
]=]
function UnlockContext:PurchaseUnlock(player: Player, targetId: string): Result.Result<boolean>
	local userId = player.UserId
	return Catch(function()
		return self.PurchaseUnlockService:Execute(player, userId, targetId)
	end, "Unlock:PurchaseUnlock")
end

function UnlockContext:GrantUnlock(player: Player, userId: number, targetId: string): Result.Result<boolean>
	return Catch(function()
		self:_EnsureUnlocksLoaded(player, userId)
		self.UnlockSyncService:MarkUnlocked(userId, targetId)

		local state = self.UnlockSyncService:GetUnlockStateReadOnly(userId)
		if state then
			Result.Try(self.UnlockPersistenceService:SaveUnlockData(player, state))
		end

		self.UnlockSyncService:HydratePlayer(player)
		return Ok(true)
	end, "Unlock:GrantUnlock")
end

--[=[
	Returns the full resolved unlock state for a player.
	@within UnlockContext
	@param userId number -- The player's user ID
	@return Result.Result<any>
]=]
function UnlockContext:GetUnlockState(userId: number): Result.Result<any>
	return Catch(function()
		return self.GetUnlockStateQuery:Execute(userId)
	end, "Unlock:GetUnlockState")
end

--[=[
	Hydrates the client with their current unlock state.
	Loads state from persistence if not yet in memory.
	@within UnlockContext
	@param player Player -- The requesting player
	@return Result.Result<boolean>
	@yields
]=]
function UnlockContext:RequestUnlockState(player: Player): Result.Result<boolean>
	return Catch(function()
		local userId = player.UserId
		self:_EnsureUnlocksLoaded(player, userId)

		-- Reconcile progression-driven unlocks before hydrating to recover from missed runtime events.
		self.EvaluateChapterAdvancementService:Execute(player, userId)
		self.EvaluateAllUnlocksService:Execute(player, userId)

		self.UnlockSyncService:HydratePlayer(player)
		return Ok(true)
	end, "Unlock:RequestUnlockState")
end

---
-- Client API
---

--[=[
	@within UnlockContext
	@client
]=]
function UnlockContext.Client:PurchaseUnlock(player: Player, targetId: string)
	return self.Server:PurchaseUnlock(player, targetId)
end

--[=[
	@within UnlockContext
	@client
]=]
function UnlockContext.Client:RequestUnlockState(player: Player)
	return self.Server:RequestUnlockState(player)
end

WrapContext(UnlockContext, "UnlockContext")

return UnlockContext
