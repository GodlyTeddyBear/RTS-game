--!strict
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.QuestSyncServer)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Catch = Result.Catch
local Ok = Result.Ok
local Err = Result.Err
local Events = GameEvents.Events

-- Data access
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

-- Domain Policies
local DepartPolicy = require(script.Parent.QuestDomain.Policies.DepartPolicy)
local FleePolicy = require(script.Parent.QuestDomain.Policies.FleePolicy)

-- Persistence Infrastructure
local QuestSyncService = require(script.Parent.Infrastructure.Persistence.QuestSyncService)
local QuestPersistenceService = require(script.Parent.Infrastructure.Persistence.QuestPersistenceService)

-- Application Services
local AcknowledgeExpedition = require(script.Parent.Application.Commands.AcknowledgeExpedition)
local DepartOnQuest = require(script.Parent.Application.Commands.DepartOnQuest)
local EndExpedition = require(script.Parent.Application.Commands.EndExpedition)
local FleeExpedition = require(script.Parent.Application.Commands.FleeExpedition)
local UseExpeditionConsumable = require(script.Parent.Application.Commands.UseExpeditionConsumable)

local QuestTypes = require(ReplicatedStorage.Contexts.Quest.Types.QuestTypes)

type TQuestState = QuestTypes.TQuestState
type TDepartResult = DepartOnQuest.TDepartResult
type TEndExpeditionResult = EndExpedition.TEndExpeditionResult
type TFleeResult = FleeExpedition.TFleeResult
type TUseExpeditionConsumableResult = UseExpeditionConsumable.TUseExpeditionConsumableResult

--[=[
	@class QuestContext
	Knit service for the Quest bounded context. Wires lifecycle events, owns the
	registry, and provides a pure pass-through server API for quest operations.
	@server
]=]
local QuestContext = Knit.CreateService({
	Name = "QuestContext",
	Client = {},
})

---
-- Knit Lifecycle
---

--[=[
	Initialises the registry, registers all context services, and resolves
	intra-context dependencies.
	@within QuestContext
	@private
]=]
function QuestContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Raw values
	registry:Register("BlinkServer", BlinkServer)
	registry:Register("ProfileManager", ProfileManager)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("QuestContext")

	-- Domain Policies
	registry:Register("DepartPolicy", DepartPolicy.new(), "Domain")
	registry:Register("FleePolicy", FleePolicy.new(), "Domain")

	-- Infrastructure Services
	registry:Register("QuestSyncService", QuestSyncService.new(), "Infrastructure")
	registry:Register("QuestPersistenceService", QuestPersistenceService.new(), "Infrastructure")

	-- Application Services
	registry:Register("AcknowledgeExpedition", AcknowledgeExpedition.new(), "Application")
	registry:Register("EndExpedition", EndExpedition.new(), "Application")
	registry:Register("DepartOnQuest", DepartOnQuest.new(), "Application")
	registry:Register("FleeExpedition", FleeExpedition.new(), "Application")
	registry:Register("UseExpeditionConsumable", UseExpeditionConsumable.new(), "Application")

	registry:InitAll()

	-- Cache refs needed by context handlers
	self.QuestSyncService = registry:Get("QuestSyncService")
	self.QuestPersistenceService = registry:Get("QuestPersistenceService")
end

--[=[
	Resolves cross-context dependencies, starts ordered services, and subscribes
	to player lifecycle events.
	@within QuestContext
	@private
]=]
function QuestContext:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	registry:Register("GuildContext", Knit.GetService("GuildContext"))
	registry:Register("ShopContext", Knit.GetService("ShopContext"))
	registry:Register("InventoryContext", Knit.GetService("InventoryContext"))
	registry:Register("DungeonContext", Knit.GetService("DungeonContext"))
	registry:Register("NPCContext", Knit.GetService("NPCContext"))
	registry:Register("CombatContext", Knit.GetService("CombatContext"))
	registry:Register("UnlockContext", Knit.GetService("UnlockContext"))

	registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Cache application service refs
	self.AcknowledgeExpeditionService = registry:Get("AcknowledgeExpedition")
	self.EndExpeditionService = registry:Get("EndExpedition")
	self.DepartOnQuestService = registry:Get("DepartOnQuest")
	self.FleeExpeditionService = registry:Get("FleeExpedition")
	self.UseExpeditionConsumableService = registry:Get("UseExpeditionConsumable")

	-- Cache cross-context refs used directly in this context
	self.GuildContext = registry:Get("GuildContext")
	self.NPCContext = registry:Get("NPCContext")
	self.CombatContext = registry:Get("CombatContext")
	self.DungeonContext = registry:Get("DungeonContext")

	-- Subscribe to lifecycle events
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadQuestStateOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "QuestContext")
			end)
			:catch(function(err)
				warn("[QuestContext] Failed to load player data:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		self:_CleanupOnPlayerLeave(player)
	end)

end

---
-- Player Data Loading
---

--[=[
	@within QuestContext
	@private
]=]
function QuestContext:_LoadQuestStateOnPlayerJoin(player: Player)
	local userId = player.UserId
	local savedData = self.QuestPersistenceService:LoadQuestState(player)

	local state = savedData or {
		ActiveExpedition = nil,
		CompletedCount = 0,
	}

	-- Never restore an active expedition — treat it as lost on server restart
	state.ActiveExpedition = nil

	self.QuestSyncService:LoadUserQuestState(userId, state)
	self.QuestSyncService:HydratePlayer(player)
end

--[=[
	@within QuestContext
	@private
]=]
function QuestContext:_CleanupOnPlayerLeave(player: Player)
	local userId = player.UserId

	-- Stop combat and destroy NPCs
	self.CombatContext:StopCombatForUser(userId)
	self.NPCContext:DestroyAllNPCsForUser(userId)

	-- DungeonContext is registered at KnitStart; may be nil in test environments
	if self.DungeonContext then
		self.DungeonContext:DestroyDungeon(player, userId)
	end

	-- If an expedition is active: return surviving adventurers to available without awarding loot
	local expedition = self.QuestSyncService:GetActiveExpeditionReadOnly(userId)
	if expedition then
		for _, member in ipairs(expedition.Party) do
			self.GuildContext:SetAdventurerExpeditionStatus(userId, member.AdventurerId, false)
		end
	end

	-- Save quest state (CompletedCount only)
	local questState = self.QuestSyncService:GetQuestStateReadOnly(userId)
	if questState then
		self.QuestPersistenceService:SaveQuestState(player, {
			CompletedCount = questState.CompletedCount,
		})
	end

	-- Remove from sync atom
	self.QuestSyncService:RemoveUserQuestState(userId)
end

---
-- Server-to-Server API
---

--[=[
	Returns a read-only snapshot of a player's quest state. Intended for
	server-to-server calls from other Knit contexts.
	@within QuestContext
	@param userId number
	@return Result.Result<TQuestState>
]=]
function QuestContext:GetQuestStateForUser(userId: number): Result.Result<TQuestState>
	return Catch(function()
		local state = self.QuestSyncService:GetQuestStateReadOnly(userId)
		if not state then
			return Err("QuestStateNotLoaded", "Quest state not loaded", { userId = userId })
		end
		return state
	end, "Quest:GetQuestStateForUser")
end

---
-- Server API Methods
---

--[=[
	Validates eligibility and begins an expedition: builds state, marks
	adventurers, generates the dungeon, and schedules combat start.
	@within QuestContext
	@param player Player
	@param zoneId string -- ZoneConfig key identifying the target zone
	@param partyAdventurerIds {string} -- Adventurer IDs to include in the party
	@return Result.Result<TDepartResult>
]=]
function QuestContext:DepartOnQuest(
	player: Player,
	zoneId: string,
	partyAdventurerIds: { string }
): Result.Result<TDepartResult>
	local userId = player.UserId
	return Catch(function()
		local onCombatComplete = function(status: string, deadAdventurerIds: { string })
			self.EndExpeditionService:Execute(player, userId, status, deadAdventurerIds)
			self.NPCContext:DestroyAllNPCsForUser(userId)
		end
		return self.DepartOnQuestService:Execute(player, userId, zoneId, partyAdventurerIds, onCombatComplete)
	end, "Quest:DepartOnQuest")
end

--[=[
	Stops combat and ends the player's active expedition with a gold penalty.
	@within QuestContext
	@param player Player
	@return Result.Result<TFleeResult>
]=]
function QuestContext:FleeExpedition(player: Player): Result.Result<TFleeResult>
	local userId = player.UserId
	return Catch(function()
		return self.FleeExpeditionService:Execute(player, userId)
	end, "Quest:FleeExpedition")
end

function QuestContext:UseExpeditionConsumable(
	player: Player,
	slotIndex: number,
	targetNpcId: string
): Result.Result<TUseExpeditionConsumableResult>
	local userId = player.UserId
	return Catch(function()
		return self.UseExpeditionConsumableService:Execute(userId, slotIndex, targetNpcId)
	end, "Quest:UseExpeditionConsumable")
end

--[=[
	Destroys the expedition dungeon and clears the active expedition after the
	player confirms the result screen.
	@within QuestContext
	@param player Player
	@return Result.Result<boolean>
]=]
function QuestContext:AcknowledgeExpedition(player: Player): Result.Result<boolean>
	local userId = player.UserId
	return Catch(function()
		return self.AcknowledgeExpeditionService:Execute(player, userId)
	end, "Quest:AcknowledgeExpedition")
end

--[=[
	Ensures quest state is loaded for the player, then pushes it to the client
	via Blink hydration. Called by the client on join.
	@within QuestContext
	@param player Player
	@return Result.Result<boolean>
	@yields
]=]
function QuestContext:RequestQuestState(player: Player): Result.Result<boolean>
	return Catch(function()
		self:_EnsureQuestStateLoaded(player)
		self.QuestSyncService:HydratePlayer(player)
		return Ok(true)
	end, "Quest:RequestQuestState")
end

--[=[
	@within QuestContext
	@private
	@yields
]=]
function QuestContext:_EnsureQuestStateLoaded(player: Player)
	local userId = player.UserId
	if self.QuestSyncService:IsPlayerLoaded(userId) then
		return
	end
	if not PlayerLifecycleManager:IsPlayerReady(player) then
		GameEvents.Bus:Wait(Events.Persistence.PlayerReady)
	end
	local savedData = self.QuestPersistenceService:LoadQuestState(player)
	self.QuestSyncService:LoadUserQuestState(userId, savedData or {
		ActiveExpedition = nil,
		CompletedCount = 0,
	})
end

---
-- Client API Methods
---

function QuestContext.Client:DepartOnQuest(player: Player, zoneId: string, partyAdventurerIds: { string })
	return self.Server:DepartOnQuest(player, zoneId, partyAdventurerIds)
end

function QuestContext.Client:FleeExpedition(player: Player)
	return self.Server:FleeExpedition(player)
end

function QuestContext.Client:UseExpeditionConsumable(player: Player, slotIndex: number, targetNpcId: string)
	return self.Server:UseExpeditionConsumable(player, slotIndex, targetNpcId)
end

function QuestContext.Client:AcknowledgeExpedition(player: Player)
	return self.Server:AcknowledgeExpedition(player)
end

function QuestContext.Client:RequestQuestState(player: Player)
	return self.Server:RequestQuestState(player)
end

WrapContext(QuestContext, "QuestContext")

return QuestContext
