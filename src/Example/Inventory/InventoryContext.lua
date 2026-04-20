--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkServer = require(ReplicatedStorage.Network.Generated.InventorySyncServer)

-- Infrastructure Services
local InventorySyncService = require(script.Parent.Infrastructure.Services.InventorySyncService)
local InventoryPersistenceService = require(script.Parent.Infrastructure.Services.InventoryPersistenceService)

-- Domain Services
local InventoryValidator = require(script.Parent.InventoryDomain.Services.InventoryValidator)
local ItemStackingService = require(script.Parent.InventoryDomain.Services.ItemStackingService)
local CapacityService = require(script.Parent.InventoryDomain.Services.CapacityService)
local SlotManagementService = require(script.Parent.InventoryDomain.Services.SlotManagementService)

-- Application Services
local GetInventory = require(script.Parent.Application.Services.GetInventory)
local AddItem = require(script.Parent.Application.Services.AddItem)
local RemoveItem = require(script.Parent.Application.Services.RemoveItem)
local TransferItem = require(script.Parent.Application.Services.TransferItem)
local StackItems = require(script.Parent.Application.Services.StackItems)
local ClearInventory = require(script.Parent.Application.Services.ClearInventory)

-- Data access
local DataManager = require(game:GetService("ServerScriptService").Data.DataManager)

local InventoryContext = Knit.CreateService({
	Name = "InventoryContext",
	Client = {},
})

---
-- Knit Lifecycle
---

function InventoryContext:KnitInit()
	-- Create infrastructure services with dependencies

	-- Domain Services (no dependencies)
	self.InventoryValidator = InventoryValidator.new()
	self.ItemStackingService = ItemStackingService.new()
	self.CapacityService = CapacityService.new()
	self.SlotManagementService = SlotManagementService.new()

	-- Infrastructure Services
	self.PersistenceService = InventoryPersistenceService.new(DataManager)

	-- Sync Service with Blink transport
	self.SyncService = InventorySyncService.new(BlinkServer)

	-- Get the sync atom
	self.PlayerInventoriesAtom = self.SyncService:GetInventoriesAtom()

	-- Application Services (with all dependencies)
	self.GetInventory = GetInventory.new(self.PlayerInventoriesAtom)

	self.AddItem = AddItem.new(
		self.InventoryValidator,
		self.ItemStackingService,
		self.CapacityService,
		self.SlotManagementService,
		self.PlayerInventoriesAtom,
		self.PersistenceService
	)

	self.RemoveItem = RemoveItem.new(
		self.InventoryValidator,
		self.PlayerInventoriesAtom,
		self.PersistenceService
	)

	self.TransferItem = TransferItem.new(
		self.InventoryValidator,
		self.SlotManagementService,
		self.ItemStackingService,
		self.PlayerInventoriesAtom,
		self.PersistenceService
	)

	self.StackItems = StackItems.new(
		self.InventoryValidator,
		self.ItemStackingService,
		self.PlayerInventoriesAtom,
		self.PersistenceService
	)

	self.ClearInventory = ClearInventory.new(self.PlayerInventoriesAtom, self.PersistenceService)

	print("InventoryContext initialized")
end

function InventoryContext:KnitStart()
	-- Load inventory for players already in game (early joiners)
	local Players = game:GetService("Players")
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_LoadInventoryOnPlayerJoin(player)
		end)
	end

	-- Subscribe to new player joins
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:_LoadInventoryOnPlayerJoin(player)
		end)
	end)

	print("InventoryContext started")
end

---
-- Player Data Loading
---

function InventoryContext:_LoadInventoryOnPlayerJoin(player: Player)
	-- Delay to ensure DataManager has the player's profile loaded
	task.delay(0.2, function()
		if not player.Parent then
			return -- Player left before load completed
		end

		-- Load inventory from ProfileStore
		local inventoryData = self.PersistenceService:LoadInventory(player)

		local userId = player.UserId

		if not inventoryData then
			-- Initialize empty inventory using sync service
			self.SyncService:CreateInventory(userId, 200)
		else
			-- Update atom with player's loaded inventory
			-- TODO: Migrate to use sync service mutation methods when loading saved data
			local currentAtom = self.PlayerInventoriesAtom
			currentAtom(function(current)
				local updated = table.clone(current)
				updated[userId] = inventoryData
				return updated
			end)
		end

		-- Send hydration to player
		self.SyncService:HydratePlayer(player)
	end)
end

---
-- Server-to-Server API Methods (for cross-context calls)
---

--- Add item to a player's inventory (used by ShopContext, EquipmentContext, etc.)
function InventoryContext:AddItemToInventory(userId: number, itemId: string, quantity: number): (boolean, any)
	local player = game:GetService("Players"):GetPlayerByUserId(userId)
	if not player then
		return false, "Player not found"
	end
	return self.AddItem:Execute(player, userId, itemId, quantity)
end

--- Remove item from a player's inventory by slot index
function InventoryContext:RemoveItemFromInventory(userId: number, slotIndex: number, quantity: number): (boolean, any)
	local player = game:GetService("Players"):GetPlayerByUserId(userId)
	if not player then
		return false, "Player not found"
	end
	return self.RemoveItem:Execute(player, userId, slotIndex, quantity)
end

--- Get a player's current inventory state
function InventoryContext:GetPlayerInventory(userId: number): (boolean, any)
	return self.GetInventory:Execute(userId)
end

---
-- Client API Methods
---

--- Get current inventory state
function InventoryContext.Client:GetInventory(player: Player): (boolean, any)
	local userId = player.UserId
	local success, data = self.Server.GetInventory:Execute(userId)
	return success, data
end

--- Request inventory state (triggers hydration)
function InventoryContext.Client:RequestInventoryState(player: Player): boolean
	self.Server.SyncService:HydratePlayer(player)
	return true
end

--- Add item to inventory
function InventoryContext.Client:AddItem(player: Player, itemId: string, quantity: number): (boolean, any)
	local userId = player.UserId
	local success, data = self.Server.AddItem:Execute(player, userId, itemId, quantity)
	return success, data
end

--- Remove item from inventory
function InventoryContext.Client:RemoveItem(player: Player, slotIndex: number, quantity: number): (boolean, any)
	local userId = player.UserId
	local success, data = self.Server.RemoveItem:Execute(player, userId, slotIndex, quantity)
	return success, data
end

--- Transfer item between slots
function InventoryContext.Client:TransferItem(player: Player, fromSlot: number, toSlot: number): (boolean, any)
	local userId = player.UserId
	local success, data = self.Server.TransferItem:Execute(player, userId, fromSlot, toSlot)
	return success, data
end

--- Stack items of same type
function InventoryContext.Client:StackItems(player: Player, itemId: string): (boolean, any)
	local userId = player.UserId
	local success, data = self.Server.StackItems:Execute(player, userId, itemId)
	return success, data
end

--- Clear inventory (admin/testing)
function InventoryContext.Client:ClearInventory(player: Player): (boolean, any)
	local userId = player.UserId
	local success, data = self.Server.ClearInventory:Execute(player, userId)
	return success, data
end

return InventoryContext
