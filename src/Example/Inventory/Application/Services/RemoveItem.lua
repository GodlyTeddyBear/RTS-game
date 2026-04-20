--!strict
local Errors = require(script.Parent.Parent.Parent.Errors)
local DebugLogger = require(script.Parent.Parent.Parent.Config.DebugLogger)

local RemoveItem = {}
RemoveItem.__index = RemoveItem

--- Creates a new RemoveItem service
-- Constructor Injection: Receives required dependencies
function RemoveItem.new(inventoryValidator: any, playerInventoriesAtom: any, persistenceService: any)
	local self = setmetatable({}, RemoveItem)

	self.InventoryValidator = inventoryValidator
	self.PlayerInventoriesAtom = playerInventoriesAtom
	self.PersistenceService = persistenceService
	self.DebugLogger = DebugLogger.new()

	return self
end

--- Executes: Removes an item from a player's inventory
-- Flow: Validate → Update atom (decrease quantity or remove slot) → Persist
-- Returns (success: boolean, data/error: any)
function RemoveItem:Execute(player: Player, userId: number, slotIndex: number, quantity: number): (boolean, any)
	if not player or userId <= 0 then
		warn("[Inventory:RemoveItem] userId:", userId, "- Invalid player or userId")
		return false, "Invalid player or userId"
	end

	if slotIndex <= 0 or quantity <= 0 then
		warn("[Inventory:RemoveItem] userId:", userId, "- Invalid slotIndex or quantity")
		return false, "Invalid slotIndex or quantity"
	end

	-- Get current inventory
	local currentAtom = self.PlayerInventoriesAtom
	local allInventories = currentAtom()
	local playerInventory = allInventories[userId]

	if not playerInventory then
		warn("[Inventory:RemoveItem] userId:", userId, "- Inventory not found")
		return false, Errors.SLOT_EMPTY
	end

	-- Validate remove operation
	local validateSuccess, validateErrors =
		self.InventoryValidator:ValidateRemoveItem(playerInventory, slotIndex, quantity)
	if not validateSuccess then
		local errorMsg = table.concat(validateErrors, "; ")
		warn("[Inventory:RemoveItem] userId:", userId, "- Validation failed:", errorMsg)
		return false, errorMsg
	end

	self.DebugLogger:Log("RemoveItem", "Validation", "userId: " .. userId .. " - Validation passed for slot " .. slotIndex .. " x" .. quantity)

	local slot = playerInventory.Slots[slotIndex]
	local removedQuantity = 0

	-- Decrease quantity or remove slot
	if quantity >= slot.Quantity then
		-- Remove entire slot
		playerInventory.Slots[slotIndex] = nil
		playerInventory.Metadata.UsedSlots = math.max(0, playerInventory.Metadata.UsedSlots :: number - 1)
		removedQuantity = slot.Quantity
	else
		-- Decrease quantity
		slot.Quantity = slot.Quantity - quantity
		removedQuantity = quantity
	end

	-- Update timestamp
	playerInventory.Metadata.LastModified = os.time()

	-- Update atom atomically
	local success = false
	(currentAtom :: any)(function(current)
		local updated = table.clone(current)
		updated[userId] = playerInventory
		success = true
		return updated
	end)

	if success then
		self.DebugLogger:Log("RemoveItem", "SlotManagement", "userId: " .. userId .. " - Removed " .. removedQuantity .. " from slot " .. slotIndex)

		-- Persist to ProfileStore
		local persistSuccess = self.PersistenceService:SaveInventory(player, playerInventory)
		if not persistSuccess then
			warn("[Inventory:RemoveItem] userId:", userId, "- Failed to persist inventory")
			return false, "Failed to persist inventory"
		end

		self.DebugLogger:Log("RemoveItem", "Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

		return true,
			{
				Message = "Item removed successfully",
				RemovedQuantity = removedQuantity,
				SlotRemoved = quantity >= slot.Quantity,
			}
	end

	warn("[Inventory:RemoveItem] userId:", userId, "- Failed to update inventory atom")
	return false, "Failed to update inventory atom"
end

return RemoveItem
