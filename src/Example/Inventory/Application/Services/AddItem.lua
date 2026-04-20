--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)
local DebugLogger = require(script.Parent.Parent.Parent.Config.DebugLogger)

local AddItem = {}
AddItem.__index = AddItem

--- Creates a new AddItem service
-- Constructor Injection: Receives all required dependencies
function AddItem.new(
	inventoryValidator: any,
	stackingService: any,
	capacityService: any,
	slotManagementService: any,
	playerInventoriesAtom: any,
	persistenceService: any
)
	local self = setmetatable({}, AddItem)

	self.InventoryValidator = inventoryValidator
	self.StackingService = stackingService
	self.CapacityService = capacityService
	self.SlotManagementService = slotManagementService
	self.PlayerInventoriesAtom = playerInventoriesAtom
	self.PersistenceService = persistenceService
	self.DebugLogger = DebugLogger.new()

	return self
end

--- Executes: Adds an item to a player's inventory
-- Flow: Validate → Check stacking → Find slot → Update atom → Persist
-- Returns (success: boolean, data/error: any)
function AddItem:Execute(player: Player, userId: number, itemId: string, quantity: number): (boolean, any)
	if not player or userId <= 0 then
		warn("[Inventory:AddItem] userId:", userId, "- Invalid player or userId")
		return false, "Invalid player or userId"
	end

	if not itemId or quantity <= 0 then
		warn("[Inventory:AddItem] userId:", userId, "- Invalid itemId or quantity")
		return false, "Invalid itemId or quantity"
	end

	-- Get current inventory
	local currentAtom = self.PlayerInventoriesAtom
	local allInventories = currentAtom()
	local playerInventory = allInventories[userId] or {
		Slots = {},
		Metadata = {
			TotalSlots = 200,
			UsedSlots = 0,
			LastModified = 0,
		},
	}

	-- Validate add operation
	local validateSuccess, validateErrors = self.InventoryValidator:ValidateAddItem(playerInventory, itemId, quantity)
	if not validateSuccess then
		local errorMsg = table.concat(validateErrors, "; ")
		warn("[Inventory:AddItem] userId:", userId, "- Validation failed:", errorMsg)
		return false, errorMsg
	end

	self.DebugLogger:Log("AddItem", "Validation", "userId: " .. userId .. " - Validation passed for " .. itemId .. " x" .. quantity)

	local itemData = ItemConfig[itemId]
	local categoryMaxStack = math.min(itemData.maxStack, 100) -- Default to 100 if not specified

	-- Try to stack with existing items first
	local stackableSlots = self.StackingService:FindStackableSlots(playerInventory, itemId)
	local remainingQuantity = quantity

	for _, stackSlotIndex in ipairs(stackableSlots) do
		if remainingQuantity <= 0 then
			break
		end

		local slot = playerInventory.Slots[stackSlotIndex]
		local availableSpace = categoryMaxStack - slot.Quantity
		local toAdd = math.min(remainingQuantity, availableSpace)

		slot.Quantity = slot.Quantity + toAdd
		remainingQuantity = remainingQuantity - toAdd
	end

	-- Add to new slots if there's remaining quantity
	while remainingQuantity > 0 do
		local availableSlot = self.SlotManagementService:FindAvailableSlot(playerInventory)
		if not availableSlot then
			break -- No more slots available
		end

		local toAdd = math.min(remainingQuantity, categoryMaxStack)
		playerInventory.Slots[availableSlot] = {
			SlotIndex = availableSlot,
			ItemId = itemId,
			Quantity = toAdd,
			Category = itemData.category,
		}

		playerInventory.Metadata.UsedSlots = playerInventory.Metadata.UsedSlots + 1
		remainingQuantity = remainingQuantity - toAdd
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
		self.DebugLogger:Log("AddItem", "SlotManagement", "userId: " .. userId .. " - Added " .. (quantity - remainingQuantity) .. " of " .. itemId)

		-- Persist to ProfileStore
		local persistSuccess = self.PersistenceService:SaveInventory(player, playerInventory)
		if not persistSuccess then
			warn("[Inventory:AddItem] userId:", userId, "- Failed to persist inventory")
			return false, "Failed to persist inventory"
		end

		self.DebugLogger:Log("AddItem", "Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

		return true, {
			Message = "Item added successfully",
			AddedQuantity = quantity - remainingQuantity,
			RemainingQuantity = remainingQuantity,
		}
	end

	warn("[Inventory:AddItem] userId:", userId, "- Failed to update inventory atom")
	return false, "Failed to update inventory atom"
end

return AddItem
