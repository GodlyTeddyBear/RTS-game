--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local BlinkClient = require(ReplicatedStorage.Network.Generated.InventorySyncClient)

-- Infrastructure
local InventorySyncService = require(script.Parent.Infrastructure.InventorySyncService)

local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

---
-- Knit Lifecycle
---

function InventoryController:KnitInit()
	-- Create sync service with BlinkClient
	self.SyncService = InventorySyncService.new(BlinkClient)

	print("InventoryController initialized")
end

function InventoryController:KnitStart()
	local InventoryContext = Knit.GetService("InventoryContext")

	-- Store reference to server service
	self.InventoryContext = InventoryContext

	-- Start listening to Blink inventory sync
	self.SyncService:Start()

	-- Request initial state (hydration) with a small delay to ensure server is ready
	task.delay(0.3, function()
		self:RequestInventoryState()
	end)

	print("InventoryController started")
end

---
-- Public API Methods
---

--- Get the inventory atom for UI components
function InventoryController:GetInventoriesAtom()
	return self.SyncService:GetInventoriesAtom()
end

--- Request initial inventory state (hydration)
function InventoryController:RequestInventoryState()
	local _, result = self.InventoryContext:RequestInventoryState():await()
	return result
end

--- Get current inventory state
function InventoryController:GetInventory()
	local _, success, data = self.InventoryContext:GetInventory():await()
	return success, data
end

--- Add item to inventory
function InventoryController:AddItem(itemId: string, quantity: number)
	local _, success, data = self.InventoryContext:AddItem(itemId, quantity):await()
	return success, data
end

--- Remove item from inventory
function InventoryController:RemoveItem(slotIndex: number, quantity: number)
	local _, success, data = self.InventoryContext:RemoveItem(slotIndex, quantity):await()
	return success, data
end

--- Transfer item between slots
function InventoryController:TransferItem(fromSlot: number, toSlot: number)
	local _, success, data = self.InventoryContext:TransferItem(fromSlot, toSlot):await()
	return success, data
end

--- Stack items of same type
function InventoryController:StackItems(itemId: string)
	local _, success, data = self.InventoryContext:StackItems(itemId):await()
	return success, data
end

--- Clear inventory (admin/testing)
function InventoryController:ClearInventory()
	local _, success, data = self.InventoryContext:ClearInventory():await()
	return success, data
end

return InventoryController
