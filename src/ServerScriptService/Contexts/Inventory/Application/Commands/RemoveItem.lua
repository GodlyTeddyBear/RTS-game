--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local PersistInventory = require(script.Parent.Parent.PersistInventory)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
    @class RemoveItem
    Application command that removes items from a specific inventory slot.
    @server
]=]
local RemoveItem = {}
RemoveItem.__index = RemoveItem

--[=[
    Create a new RemoveItem instance (zero-arg for Registry).
    @within RemoveItem
    @return RemoveItem
]=]
function RemoveItem.new()
	local self = setmetatable({}, RemoveItem)
	return self
end

--- Pulls dependencies from the Registry
function RemoveItem:Init(registry: any, _name: string)
	self.RemoveItemPolicy = registry:Get("RemoveItemPolicy")
	self.SyncService = registry:Get("InventorySyncService")
	self.PersistenceService = registry:Get("InventoryPersistenceService")
end

--[=[
    Remove items from a player's inventory slot, clearing the slot entirely if quantity meets or exceeds contents.
    @within RemoveItem
    @param player Player -- The player whose inventory is modified
    @param userId number -- The player's UserId
    @param slotIndex number -- The slot to remove from
    @param quantity number -- How many items to remove
    @return Result<any> -- Ok with removed quantity and slot-cleared flag; Err if validation fails
]=]
function RemoveItem:Execute(player: Player, userId: number, slotIndex: number, quantity: number): Result.Result<any>
	Ensure(player ~= nil and userId > 0, "InvalidArgument", "Invalid player or userId")

	local ctx = Try(self.RemoveItemPolicy:Check(userId, slotIndex, quantity))
	local playerInventory = ctx.InventoryState
	local slot = ctx.Slot

	MentionSuccess(
		"Inventory:RemoveItem:Validation",
		"userId: " .. userId .. " - Validation passed for slot " .. slotIndex .. " x" .. quantity
	)
	local removedQuantity = 0
	local slotRemoved = false

	-- Apply changes through SyncService (centralized mutation)
	if quantity >= slot.Quantity then
		-- Remove entire slot if requested quantity meets or exceeds contents
		self.SyncService:SetSlot(userId, slotIndex, nil)
		self.SyncService:UpdateMetadata(userId, {
			UsedSlots = math.max(0, playerInventory.Metadata.UsedSlots - 1),
			LastModified = os.time(),
		})
		removedQuantity = slot.Quantity
		slotRemoved = true
	else
		-- Partial removal: decrease quantity and keep slot occupied
		self.SyncService:UpdateSlotQuantity(userId, slotIndex, slot.Quantity - quantity)
		self.SyncService:UpdateMetadata(userId, { LastModified = os.time() })
		removedQuantity = quantity
	end

	MentionSuccess(
		"Inventory:RemoveItem:SlotManagement",
		"userId: " .. userId .. " - Removed " .. removedQuantity .. " from slot " .. slotIndex
	)

	PersistInventory(self.SyncService, self.PersistenceService, player, userId)

	MentionSuccess("Inventory:RemoveItem:Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

	return Ok({
		Message = "Item removed successfully",
		RemovedQuantity = removedQuantity,
		SlotRemoved = slotRemoved,
	})
end

return RemoveItem
