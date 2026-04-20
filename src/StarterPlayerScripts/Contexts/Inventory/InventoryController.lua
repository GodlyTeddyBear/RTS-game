--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local BlinkClient = require(ReplicatedStorage.Network.Generated.InventorySyncClient)

-- Infrastructure
local InventorySyncService = require(script.Parent.Infrastructure.InventorySyncService)

--[=[
	@class InventoryController
	Client-side Knit controller managing inventory state synchronization and item operations.
	@client
]=]
local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

---
-- Knit Lifecycle
---

function InventoryController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	-- Create sync service with BlinkClient
	self.SyncService = InventorySyncService.new(BlinkClient)
	registry:Register("InventorySyncService", self.SyncService, "Infrastructure")

	registry:InitAll()

	print("InventoryController initialized")
end

function InventoryController:KnitStart()
	local registry = self.Registry

	-- Resolve cross-context dependencies
	local InventoryContext = Knit.GetService("InventoryContext")
	registry:Register("InventoryContext", InventoryContext)

	-- Store reference to server service
	self.InventoryContext = InventoryContext

	registry:StartOrdered({ "Infrastructure" })

	-- Request initial state (hydration) with a small delay to ensure server is ready
	task.delay(0.3, function()
		self:RequestInventoryState()
	end)

	print("InventoryController started")
end

---
-- Public API Methods
---

--[=[
	Get the inventory atom for UI components.
	@within InventoryController
	@return Charm.Atom<InventoryState> -- Reactive atom containing inventory state
]=]
function InventoryController:GetInventoriesAtom()
	return self.SyncService:GetInventoriesAtom()
end

--[=[
	Request initial inventory state from server (hydration).
	@within InventoryController
	@return Result<void>
	@yields
]=]
function InventoryController:RequestInventoryState()
	return self.InventoryContext:RequestInventoryState()
		:catch(function(err)
			warn("[InventoryController:RequestInventoryState]", err.type, err.message)
		end)
end

--[=[
	Retrieve current inventory state.
	@within InventoryController
	@return Result<InventoryState> -- Complete inventory data
	@yields
]=]
function InventoryController:GetInventory()
	return self.InventoryContext:GetInventory()
		:catch(function(err)
			warn("[InventoryController:GetInventory]", err.type, err.message)
		end)
end

--[=[
	Add item to inventory.
	@within InventoryController
	@param itemId string -- Item identifier from ItemConfig
	@param quantity number -- Number of items to add
	@return Result<void>
	@yields
]=]
function InventoryController:AddItem(itemId: string, quantity: number)
	return self.InventoryContext:AddItem(itemId, quantity)
		:catch(function(err)
			warn("[InventoryController:AddItem]", err.type, err.message)
		end)
end

--[=[
	Remove item from inventory.
	@within InventoryController
	@param slotIndex number -- Slot index (1-based)
	@param quantity number -- Number to remove; if greater than stack, removes entire stack
	@return Result<void>
	@yields
]=]
function InventoryController:RemoveItem(slotIndex: number, quantity: number)
	return self.InventoryContext:RemoveItem(slotIndex, quantity)
		:catch(function(err)
			warn("[InventoryController:RemoveItem]", err.type, err.message)
		end)
end

--[=[
	Transfer item between slots.
	@within InventoryController
	@param fromSlot number -- Source slot index
	@param toSlot number -- Destination slot index
	@return Result<void>
	@yields
]=]
function InventoryController:TransferItem(fromSlot: number, toSlot: number)
	return self.InventoryContext:TransferItem(fromSlot, toSlot)
		:catch(function(err)
			warn("[InventoryController:TransferItem]", err.type, err.message)
		end)
end

--[=[
	Stack all items of the same type.
	@within InventoryController
	@param itemId string -- Item identifier to stack
	@return Result<void>
	@yields
]=]
function InventoryController:StackItems(itemId: string)
	return self.InventoryContext:StackItems(itemId)
		:catch(function(err)
			warn("[InventoryController:StackItems]", err.type, err.message)
		end)
end

--[=[
	Clear inventory (admin/testing only).
	@within InventoryController
	@return Result<void>
	@yields
]=]
function InventoryController:ClearInventory()
	return self.InventoryContext:ClearInventory()
		:catch(function(err)
			warn("[InventoryController:ClearInventory]", err.type, err.message)
		end)
end

return InventoryController
