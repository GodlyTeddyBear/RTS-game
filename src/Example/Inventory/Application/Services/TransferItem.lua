--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Errors = require(script.Parent.Parent.Parent.Errors)
local DebugLogger = require(script.Parent.Parent.Parent.Config.DebugLogger)

local TransferItem = {}
TransferItem.__index = TransferItem

--- Creates a new TransferItem service
-- Constructor Injection: Receives required dependencies
function TransferItem.new(
	inventoryValidator: any,
	slotManagementService: any,
	stackingService: any,
	playerInventoriesAtom: any,
	persistenceService: any
)
	local self = setmetatable({}, TransferItem)

	self.InventoryValidator = inventoryValidator
	self.SlotManagementService = slotManagementService
	self.StackingService = stackingService
	self.PlayerInventoriesAtom = playerInventoriesAtom
	self.PersistenceService = persistenceService
	self.DebugLogger = DebugLogger.new()

	return self
end

--- Executes: Transfers an item between two slots
-- Handles: Swapping items, merging stacks, moving to empty slot
-- Returns (success: boolean, data/error: any)
function TransferItem:Execute(player: Player, userId: number, fromSlot: number, toSlot: number): (boolean, any)
	if not player or userId <= 0 then
		warn("[Inventory:TransferItem] userId:", userId, "- Invalid player or userId")
		return false, "Invalid player or userId"
	end

	if fromSlot <= 0 or toSlot <= 0 then
		warn("[Inventory:TransferItem] userId:", userId, "- Invalid slot indices")
		return false, "Invalid slot indices"
	end

	if fromSlot == toSlot then
		warn("[Inventory:TransferItem] userId:", userId, "- Source and destination slots are the same")
		return false, "Source and destination slots are the same"
	end

	-- Get current inventory
	local currentAtom = self.PlayerInventoriesAtom
	local allInventories = currentAtom()
	local playerInventory = allInventories[userId]

	if not playerInventory then
		warn("[Inventory:TransferItem] userId:", userId, "- Inventory not found")
		return false, Errors.SLOT_EMPTY
	end

	-- Validate transfer operation
	local validateSuccess, validateErrors =
		self.InventoryValidator:ValidateTransferItem(playerInventory, fromSlot, toSlot)
	if not validateSuccess then
		local errorMsg = table.concat(validateErrors, "; ")
		warn("[Inventory:TransferItem] userId:", userId, "- Validation failed:", errorMsg)
		return false, errorMsg
	end

	self.DebugLogger:Log("TransferItem", "Validation", "userId: " .. userId .. " - Validation passed for slot " .. fromSlot .. " -> " .. toSlot)

	local fromSlotData = playerInventory.Slots[fromSlot]
	local toSlotData = playerInventory.Slots[toSlot]

	if not fromSlotData then
		warn("[Inventory:TransferItem] userId:", userId, "- Source slot empty")
		return false, Errors.SLOT_EMPTY
	end

	-- Handle different transfer cases
	if toSlotData then
		-- Destination slot is occupied
		if
			fromSlotData.ItemId == toSlotData.ItemId
			and self.StackingService:CanStack(fromSlotData.ItemId, toSlotData.ItemId)
		then
			-- Merge stacks
			local availableSpace = self.StackingService:GetAvailableStackSpace(toSlotData)
			local toTransfer = math.min(fromSlotData.Quantity, availableSpace)

			toSlotData.Quantity = toSlotData.Quantity + toTransfer
			fromSlotData.Quantity = fromSlotData.Quantity - toTransfer

			-- Remove source slot if empty
			if fromSlotData.Quantity <= 0 then
				playerInventory.Slots[fromSlot] = nil
				playerInventory.Metadata.UsedSlots = math.max(0, playerInventory.Metadata.UsedSlots :: number - 1)
			end
		else
			-- Swap items
			playerInventory.Slots[fromSlot] = toSlotData
			playerInventory.Slots[toSlot] = fromSlotData

			-- Update slot indices
			if playerInventory.Slots[fromSlot] then
				playerInventory.Slots[fromSlot].SlotIndex = fromSlot
			end
			if playerInventory.Slots[toSlot] then
				playerInventory.Slots[toSlot].SlotIndex = toSlot
			end
		end
	else
		-- Destination slot is empty - move item
		playerInventory.Slots[toSlot] = fromSlotData
		playerInventory.Slots[fromSlot] = nil
		playerInventory.Slots[toSlot].SlotIndex = toSlot
		-- UsedSlots unchanged since we're just moving, not creating or destroying
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
		self.DebugLogger:Log("TransferItem", "SlotManagement", "userId: " .. userId .. " - Transferred slot " .. fromSlot .. " -> " .. toSlot)

		-- Persist to ProfileStore
		local persistSuccess = self.PersistenceService:SaveInventory(player, playerInventory)
		if not persistSuccess then
			warn("[Inventory:TransferItem] userId:", userId, "- Failed to persist inventory")
			return false, "Failed to persist inventory"
		end

		self.DebugLogger:Log("TransferItem", "Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

		return true, {
			Message = "Item transferred successfully",
		}
	end

	warn("[Inventory:TransferItem] userId:", userId, "- Failed to update inventory atom")
	return false, "Failed to update inventory atom"
end

return TransferItem
