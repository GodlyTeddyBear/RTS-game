--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.InventorySyncServer)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local Catch = Result.Catch
local Try = Result.Try
local fromNilable = Result.fromNilable

-- Persistence Infrastructure
local InventorySyncService = require(script.Parent.Infrastructure.Persistence.InventorySyncService)
local InventoryPersistenceService = require(script.Parent.Infrastructure.Persistence.InventoryPersistenceService)

-- Domain Services
local ItemStackingService = require(script.Parent.InventoryDomain.Services.ItemStackingService)
local CapacityService = require(script.Parent.InventoryDomain.Services.CapacityService)
local SlotManagementService = require(script.Parent.InventoryDomain.Services.SlotManagementService)

-- Domain Policies
local AddItemPolicy = require(script.Parent.InventoryDomain.Policies.AddItemPolicy)
local RemoveItemPolicy = require(script.Parent.InventoryDomain.Policies.RemoveItemPolicy)
local TransferItemPolicy = require(script.Parent.InventoryDomain.Policies.TransferItemPolicy)
local StackItemsPolicy = require(script.Parent.InventoryDomain.Policies.StackItemsPolicy)

-- Application Commands
local AddItem = require(script.Parent.Application.Commands.AddItem)
local RemoveItem = require(script.Parent.Application.Commands.RemoveItem)
local TransferItem = require(script.Parent.Application.Commands.TransferItem)
local StackItems = require(script.Parent.Application.Commands.StackItems)
local ClearInventory = require(script.Parent.Application.Commands.ClearInventory)

-- Application Queries
local GetInventory = require(script.Parent.Application.Queries.GetInventory)

-- Data access
local ProfileManager = require(game:GetService("ServerScriptService").Persistence.ProfileManager)
local PlayerLifecycleManager = require(game:GetService("ServerScriptService").Persistence.PlayerLifecycleManager)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events

--[=[
    @class InventoryContext
    Knit service that exposes the Inventory bounded context to the server and connected clients.
    @server
]=]
local InventoryContext = Knit.CreateService({
	Name = "InventoryContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function InventoryContext:KnitInit()
	-- Build the context registry
	local registry = Registry.new("Server")

	-- Register raw values
	registry:Register("ProfileManager", ProfileManager)
	registry:Register("BlinkServer", BlinkServer)

	-- Register as lifecycle loader
	PlayerLifecycleManager:RegisterLoader("InventoryContext")

	-- Domain Services (no dependencies)
	registry:Register("ItemStackingService", ItemStackingService.new(), "Domain")
	registry:Register("CapacityService", CapacityService.new(), "Domain")
	registry:Register("SlotManagementService", SlotManagementService.new(), "Domain")

	-- Domain Policies (depend on Infrastructure)
	registry:Register("AddItemPolicy", AddItemPolicy.new(), "Domain")
	registry:Register("RemoveItemPolicy", RemoveItemPolicy.new(), "Domain")
	registry:Register("TransferItemPolicy", TransferItemPolicy.new(), "Domain")
	registry:Register("StackItemsPolicy", StackItemsPolicy.new(), "Domain")

	-- Infrastructure Services
	registry:Register("InventoryPersistenceService", InventoryPersistenceService.new(), "Infrastructure")
	registry:Register("InventorySyncService", InventorySyncService.new(), "Infrastructure")

	-- Application Services
	registry:Register("GetInventory", GetInventory.new(), "Application")
	registry:Register("AddItem", AddItem.new(), "Application")
	registry:Register("RemoveItem", RemoveItem.new(), "Application")
	registry:Register("TransferItem", TransferItem.new(), "Application")
	registry:Register("StackItems", StackItems.new(), "Application")
	registry:Register("ClearInventory", ClearInventory.new(), "Application")

	-- Wire all dependencies
	registry:InitAll()

	-- Cache refs on self
	self.ItemStackingService = registry:Get("ItemStackingService")
	self.CapacityService = registry:Get("CapacityService")
	self.SlotManagementService = registry:Get("SlotManagementService")
	self.PersistenceService = registry:Get("InventoryPersistenceService")
	self.SyncService = registry:Get("InventorySyncService")
	self.GetInventory = registry:Get("GetInventory")
	self.AddItem = registry:Get("AddItem")
	self.RemoveItem = registry:Get("RemoveItem")
	self.TransferItem = registry:Get("TransferItem")
	self.StackItems = registry:Get("StackItems")
	self.ClearInventory = registry:Get("ClearInventory")

	-- Get the sync atom
	self.PlayerInventoriesAtom = self.SyncService:GetInventoriesAtom()

	print("InventoryContext initialized")
end

function InventoryContext:KnitStart()
	-- Subscribe to lifecycle events
	GameEvents.Bus:On(Events.Persistence.ProfileLoaded, function(player)
		ProfileManager:WaitForData(player)
			:andThen(function()
				self:_LoadInventoryOnPlayerJoin(player)
				PlayerLifecycleManager:NotifyLoaded(player, "InventoryContext")
			end)
			:catch(function(err)
				warn("[InventoryContext] Failed to load player data:", tostring(err))
			end)
	end)

end

---
-- Player Data Loading
---

function InventoryContext:_LoadInventoryOnPlayerJoin(player: Player)
	local inventoryData = self.PersistenceService:LoadInventory(player)
	local userId = player.UserId

	if not inventoryData then
		self.SyncService:CreateInventory(userId, 200)
	else
		local currentAtom = self.PlayerInventoriesAtom
		currentAtom(function(current)
			local updated = table.clone(current)
			updated[userId] = inventoryData
			return updated
		end)
	end

	self.SyncService:HydratePlayer(player)
end

---
-- Server-to-Server API Methods (for cross-context calls)
-- These return Result directly so callers can use Try.
---

--[=[
    Add an item to a player's inventory; intended for cross-context server calls.
    @within InventoryContext
    @param userId number -- The player's UserId
    @param itemId string -- The item ID to add (must exist in ItemConfig)
    @param quantity number -- How many items to add
    @return Result<any> -- Ok on success, Err if item invalid, quantity invalid, or inventory full
]=]
function InventoryContext:AddItemToInventory(userId: number, itemId: string, quantity: number): Result.Result<any>
	return Catch(function()
		local player = Try(fromNilable(game:GetService("Players"):GetPlayerByUserId(userId), "PlayerNotFound", "Player not found", { userId = userId }))
		return self.AddItem:Execute(player, userId, itemId, quantity)
	end, "Inventory:AddItemToInventory")
end

--[=[
    Remove an item from a player's inventory by slot index; intended for cross-context server calls.
    @within InventoryContext
    @param userId number -- The player's UserId
    @param slotIndex number -- The slot to remove from
    @param quantity number -- How many items to remove
    @return Result<any> -- Ok on success, Err if slot invalid, empty, or insufficient quantity
]=]
function InventoryContext:RemoveItemFromInventory(
	userId: number,
	slotIndex: number,
	quantity: number
): Result.Result<any>
	return Catch(function()
		local player = Try(fromNilable(game:GetService("Players"):GetPlayerByUserId(userId), "PlayerNotFound", "Player not found", { userId = userId }))
		return self.RemoveItem:Execute(player, userId, slotIndex, quantity)
	end, "Inventory:RemoveItemFromInventory")
end

--[=[
    Get a player's current inventory state; intended for cross-context server calls.
    @within InventoryContext
    @param userId number -- The player's UserId
    @return Result<any> -- Ok with the inventory state table, or an empty inventory if not found
]=]
function InventoryContext:GetPlayerInventory(userId: number): Result.Result<any>
	return Catch(function()
		return self.GetInventory:Execute(userId)
	end, "Inventory:GetPlayerInventory")
end

---
-- Client API Methods
---

--[=[
    Get the calling player's current inventory state.
    @within InventoryContext
    @param player Player -- The requesting player (injected by Knit)
    @return Result<any> -- Ok with the inventory state table
]=]
function InventoryContext.Client:GetInventory(player: Player)
	local userId = player.UserId
	return Catch(function()
		return self.Server.GetInventory:Execute(userId)
	end, "Inventory.Client:GetInventory")
end

--[=[
    Trigger a full inventory hydration push to the requesting player.
    @within InventoryContext
    @param player Player -- The requesting player (injected by Knit)
    @return boolean -- Always returns true
]=]
function InventoryContext.Client:RequestInventoryState(player: Player): boolean
	self.Server.SyncService:HydratePlayer(player)
	return true
end

--[=[
    Add an item to the calling player's inventory.
    @within InventoryContext
    @param player Player -- The requesting player (injected by Knit)
    @param itemId string -- The item ID to add
    @param quantity number -- How many items to add
    @return Result<any> -- Ok on success, Err if validation fails or inventory is full
]=]
function InventoryContext.Client:AddItem(player: Player, itemId: string, quantity: number)
	local userId = player.UserId
	return Catch(function()
		return self.Server.AddItem:Execute(player, userId, itemId, quantity)
	end, "Inventory.Client:AddItem")
end

--[=[
    Remove an item from the calling player's inventory.
    @within InventoryContext
    @param player Player -- The requesting player (injected by Knit)
    @param slotIndex number -- The slot to remove from
    @param quantity number -- How many items to remove
    @return Result<any> -- Ok on success, Err if slot invalid, empty, or insufficient quantity
]=]
function InventoryContext.Client:RemoveItem(player: Player, slotIndex: number, quantity: number)
	local userId = player.UserId
	return Catch(function()
		return self.Server.RemoveItem:Execute(player, userId, slotIndex, quantity)
	end, "Inventory.Client:RemoveItem")
end

--[=[
    Transfer an item between two slots in the calling player's inventory.
    @within InventoryContext
    @param player Player -- The requesting player (injected by Knit)
    @param fromSlot number -- Source slot index
    @param toSlot number -- Destination slot index
    @return Result<any> -- Ok on success, Err if either slot is invalid or source is empty
]=]
function InventoryContext.Client:TransferItem(player: Player, fromSlot: number, toSlot: number)
	local userId = player.UserId
	return Catch(function()
		return self.Server.TransferItem:Execute(player, userId, fromSlot, toSlot)
	end, "Inventory.Client:TransferItem")
end

--[=[
    Consolidate all slots of the same item into the fewest possible slots.
    @within InventoryContext
    @param player Player -- The requesting player (injected by Knit)
    @param itemId string -- The item ID to consolidate
    @return Result<any> -- Ok with consolidation summary, Err if item invalid or not stackable
]=]
function InventoryContext.Client:StackItems(player: Player, itemId: string)
	local userId = player.UserId
	return Catch(function()
		return self.Server.StackItems:Execute(player, userId, itemId)
	end, "Inventory.Client:StackItems")
end

--[=[
    Clear all items from the calling player's inventory (admin/testing only).
    @within InventoryContext
    @param player Player -- The requesting player (injected by Knit)
    @return Result<any> -- Ok on success, Err if inventory not found
]=]
function InventoryContext.Client:ClearInventory(player: Player)
	local userId = player.UserId
	return Catch(function()
		return self.Server.ClearInventory:Execute(player, userId)
	end, "Inventory.Client:ClearInventory")
end

WrapContext(InventoryContext, "InventoryContext")

return InventoryContext
