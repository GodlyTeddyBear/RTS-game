--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.GuildSyncServer)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Catch = Result.Catch
local Err = Result.Err
local Try = Result.Try
local Events = GameEvents.Events

-- Data access
local ProfileManager = require(ServerScriptService.Persistence.ProfileManager)
local PlayerLifecycleManager = require(ServerScriptService.Persistence.PlayerLifecycleManager)

-- Domain Services
local StatCalculator = require(script.Parent.GuildDomain.Services.StatCalculator)

-- Domain Policies
local HirePolicy = require(script.Parent.GuildDomain.Policies.HirePolicy)
local EquipPolicy = require(script.Parent.GuildDomain.Policies.EquipPolicy)
local UnequipPolicy = require(script.Parent.GuildDomain.Policies.UnequipPolicy)

-- Persistence Infrastructure
local GuildSyncService = require(script.Parent.Infrastructure.Persistence.GuildSyncService)
local GuildPersistenceService = require(script.Parent.Infrastructure.Persistence.GuildPersistenceService)

-- Application Services
local HireAdventurer = require(script.Parent.Application.Commands.HireAdventurer)
local EquipItem = require(script.Parent.Application.Commands.EquipItem)
local UnequipItem = require(script.Parent.Application.Commands.UnequipItem)

local AdventurerTypes = require(ReplicatedStorage.Contexts.Guild.Types.AdventurerTypes)
type TAdventurer = AdventurerTypes.TAdventurer
type THireResult = HireAdventurer.THireResult
type TEquipResult = EquipItem.TEquipResult
type TUnequipResult = UnequipItem.TUnequipResult

--[=[
	@class GuildContext
	Orchestrates adventurer hiring, equipment management, and roster persistence.
	Exposes server-to-server APIs and client-facing commands within the DDD pattern.
	@server
]=]
local GuildContext = Knit.CreateService({
	Name = "GuildContext",
	Client = {},
})

---
-- Knit Lifecycle
---

--[=[
	Initialize the registry with all Guild services and their dependencies.
	@within GuildContext
]=]
function GuildContext:KnitInit()
	local registry = Registry.new("Server")
	self.Registry = registry

	-- Raw values
	registry:Register("BlinkServer", BlinkServer)
	registry:Register("ProfileManager", ProfileManager)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("GuildContext")

	-- Domain Services (no external dependencies)
	registry:Register("StatCalculator", StatCalculator.new(), "Domain")

	-- Domain Policies (depend on Infrastructure and cross-context services)
	registry:Register("HirePolicy", HirePolicy.new(), "Domain")
	registry:Register("EquipPolicy", EquipPolicy.new(), "Domain")
	registry:Register("UnequipPolicy", UnequipPolicy.new(), "Domain")

	-- Infrastructure Services
	registry:Register("GuildSyncService", GuildSyncService.new(), "Infrastructure")
	registry:Register("GuildPersistenceService", GuildPersistenceService.new(), "Infrastructure")

	-- Application Services
	registry:Register("HireAdventurer", HireAdventurer.new(), "Application")
	registry:Register("EquipItem", EquipItem.new(), "Application")
	registry:Register("UnequipItem", UnequipItem.new(), "Application")

	registry:InitAll()

	-- Cache refs needed by context handlers
	self.StatCalculator = registry:Get("StatCalculator")
	self.GuildSyncService = registry:Get("GuildSyncService")
	self.GuildPersistenceService = registry:Get("GuildPersistenceService")
end

--[=[
	Start all registry services, resolve cross-context dependencies, and subscribe to lifecycle events.
	@within GuildContext
]=]
function GuildContext:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	registry:Register("ShopContext", Knit.GetService("ShopContext"))
	registry:Register("InventoryContext", Knit.GetService("InventoryContext"))

	-- Start registry layers in dependency order (Domain → Infrastructure → Application)
	registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Cache application service refs
	self.HireAdventurer = registry:Get("HireAdventurer")
	self.EquipItem = registry:Get("EquipItem")
	self.UnequipItem = registry:Get("UnequipItem")

	-- Subscribe to lifecycle events to hydrate and cleanup player guild state
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadAdventurersOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "GuildContext")
			end)
			:catch(function(err)
				warn("[GuildContext] Failed to load player data:", tostring(err))
			end)
	end)

	GameEvents.Bus:On(Events.Persistence.ProfileSaving, function(player)
		self:_CleanupOnPlayerLeave(player)
	end)

	print("GuildContext started")
end

---
-- Player Data Loading
---

-- Load persisted adventurers on join, clear stale expedition flags, and sync to client.
function GuildContext:_LoadAdventurersOnPlayerJoin(player: Player)
	local adventurersData = self.GuildPersistenceService:LoadAdventurers(player)
	local userId = player.UserId

	-- Step 1: Clear expedition flags to prevent carrying over stale state
	-- (expedition state does not survive server restarts or disconnects mid-expedition)
	if adventurersData then
		for _, adventurer in pairs(adventurersData) do
			adventurer.IsOnExpedition = false
		end
	end

	-- Step 2: Load roster into sync atom (defaults to empty table if no persisted data)
	self.GuildSyncService:LoadUserAdventurers(userId, adventurersData or {})

	-- Step 3: Hydrate client with initial state
	self.GuildSyncService:HydratePlayer(player)
end

-- Persist guild state and remove from sync on player leave.
function GuildContext:_CleanupOnPlayerLeave(player: Player)
	local userId = player.UserId

	-- Step 1: Persist current state before cleanup, clearing expedition flags
	-- (prevents expedition state from blocking future departures on reconnect)
	local adventurers = self.GuildSyncService:GetAdventurersReadOnly(userId)
	if adventurers then
		for _, adventurer in pairs(adventurers) do
			adventurer.IsOnExpedition = false
		end
		Try(self.GuildPersistenceService:SaveAllAdventurers(player, adventurers))
	end

	-- Step 2: Remove user data from in-memory sync
	self.GuildSyncService:RemoveUserAdventurers(userId)
end

---
-- Server-to-Server API (for cross-context calls)
---

--[=[
	Fetch all adventurers for a user (read-only copy).
	@within GuildContext
	@param userId number -- The player's user ID
	@return Result<{[string]: TAdventurer}> -- Roster keyed by adventurer ID
	@error AdventurersNotLoaded -- Adventurers not yet loaded for this user
]=]
function GuildContext:GetAdventurersForUser(userId: number): Result.Result<{ [string]: TAdventurer }>
	return Catch(function()
		local adventurers = self.GuildSyncService:GetAdventurersReadOnly(userId)
		if not adventurers then
			return Err("AdventurersNotLoaded", "Adventurers not loaded", { userId = userId })
		end
		return adventurers
	end, "Guild:GetAdventurersForUser")
end

--[=[
	Mark an adventurer as departed on an expedition.
	@within GuildContext
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@return Result<boolean> -- Success status
	@error AdventurerNotFound -- Adventurer not found in roster
]=]
function GuildContext:MarkAdventurerDeparted(userId: number, adventurerId: string): Result.Result<boolean>
	return self:SetAdventurerExpeditionStatus(userId, adventurerId, true)
end

--[=[
	Return an adventurer to the available roster after an expedition.
	@within GuildContext
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@return Result<boolean> -- Success status
	@error AdventurerNotFound -- Adventurer not found in roster
]=]
function GuildContext:MarkAdventurerReturned(userId: number, adventurerId: string): Result.Result<boolean>
	return self:SetAdventurerExpeditionStatus(userId, adventurerId, false)
end

--[=[
	Set the expedition status (IsOnExpedition flag) for an adventurer.
	@within GuildContext
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@param isOnExpedition boolean -- Whether the adventurer is on expedition
	@return Result<boolean> -- Success status
	@error AdventurerNotFound -- Adventurer not found in roster
]=]
function GuildContext:SetAdventurerExpeditionStatus(
	userId: number,
	adventurerId: string,
	isOnExpedition: boolean
): Result.Result<boolean>
	return Catch(function()
		local adventurer = self.GuildSyncService:GetAdventurerReadOnly(userId, adventurerId)
		if not adventurer then
			return Err("AdventurerNotFound", "Adventurer not found", { userId = userId, adventurerId = adventurerId })
		end
		self.GuildSyncService:SetAdventurerExpeditionStatus(userId, adventurerId, isOnExpedition)
		return true
	end, "Guild:SetAdventurerExpeditionStatus")
end

--[=[
	Permanently remove an adventurer (permadeath).
	@within GuildContext
	@param player Player -- The player whose adventurer to remove
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@return Result<boolean> -- Success status
	@error AdventurerNotFound -- Adventurer not found in roster
]=]
function GuildContext:RemoveAdventurer(player: Player, userId: number, adventurerId: string): Result.Result<boolean>
	return Catch(function()
		self.GuildSyncService:RemoveAdventurer(userId, adventurerId)
		Try(self.GuildPersistenceService:RemoveAdventurer(player, adventurerId))
		return true
	end, "Guild:RemoveAdventurer")
end

--[=[
	Fetch a specific adventurer for a user (read-only copy).
	@within GuildContext
	@param userId number -- The player's user ID
	@param adventurerId string -- The adventurer's ID
	@return Result<TAdventurer> -- The adventurer data
	@error AdventurerNotFound -- Adventurer not found in roster
]=]
function GuildContext:GetAdventurerForUser(userId: number, adventurerId: string): Result.Result<TAdventurer>
	return Catch(function()
		local adventurer = self.GuildSyncService:GetAdventurerReadOnly(userId, adventurerId)
		if not adventurer then
			return Err("AdventurerNotFound", "Adventurer not found", { userId = userId, adventurerId = adventurerId })
		end
		return adventurer
	end, "Guild:GetAdventurerForUser")
end

---
-- Client API Methods
---

--[=[
	Hire a new adventurer of the specified type.
	@within GuildContext
	@param player Player -- The player hiring the adventurer
	@param adventurerType string -- The type key from AdventurerConfig
	@return Result<THireResult> -- Adventurer ID, type, and hire cost
	@error InvalidAdventurerType -- Type does not exist in config
	@error RosterFull -- Roster is at maximum capacity
	@error InsufficientGold -- Player lacks gold for hire cost
]=]
function GuildContext.Client:HireAdventurer(player: Player, adventurerType: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.HireAdventurer:Execute(player, userId, adventurerType)
	end, "Guild.Client:HireAdventurer")
end

--[=[
	Equip an item from the player's inventory to an adventurer.
	@within GuildContext
	@param player Player -- The player equipping the item
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
	@param inventorySlotIndex number -- Inventory slot index
	@return Result<TEquipResult> -- Adventurer ID, slot type, item ID, and previous item ID if any
	@error AdventurerNotFound -- Adventurer not found in roster
	@error InvalidSlotType -- Slot type is invalid
	@error ItemNotInInventory -- Inventory slot is empty
	@error ItemNotEquippable -- Item category cannot be equipped in this slot
]=]
function GuildContext.Client:EquipItem(
	player: Player,
	adventurerId: string,
	slotType: string,
	inventorySlotIndex: number
)
	local userId = player.UserId
	return Catch(function()
		return self.Server.EquipItem:Execute(player, userId, adventurerId, slotType, inventorySlotIndex)
	end, "Guild.Client:EquipItem")
end

--[=[
	Unequip an item from an adventurer's equipment slot.
	@within GuildContext
	@param player Player -- The player unequipping the item
	@param adventurerId string -- The adventurer's ID
	@param slotType string -- Equipment slot type (Weapon, Armor, or Accessory)
	@return Result<TUnequipResult> -- Adventurer ID, slot type, and returned item ID
	@error AdventurerNotFound -- Adventurer not found in roster
	@error InvalidSlotType -- Slot type is invalid
	@error SlotAlreadyEmpty -- Equipment slot is already empty
]=]
function GuildContext.Client:UnequipItem(player: Player, adventurerId: string, slotType: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.UnequipItem:Execute(player, userId, adventurerId, slotType)
	end, "Guild.Client:UnequipItem")
end

--[=[
	Request initial guild state hydration to the player.
	Loads persisted data if not yet in memory, then syncs to client.
	@within GuildContext
	@param player Player -- The player requesting state
	@return boolean -- Always true
]=]
function GuildContext.Client:RequestGuildState(player: Player): boolean
	local userId = player.UserId

	-- Load from persistence if not yet in memory
	if not self.Server.GuildSyncService:IsPlayerLoaded(userId) then
		-- Guard against race: wait for profile if not yet ready
		if not PlayerLifecycleManager:IsPlayerReady(player) then
			GameEvents.Bus:Wait(Events.Persistence.PlayerReady)
		end
		local adventurersData = self.Server.GuildPersistenceService:LoadAdventurers(player)
		self.Server.GuildSyncService:LoadUserAdventurers(userId, adventurersData or {})
	end

	-- Sync state to client
	self.Server.GuildSyncService:HydratePlayer(player)
	return true
end

WrapContext(GuildContext, "GuildContext")

return GuildContext
