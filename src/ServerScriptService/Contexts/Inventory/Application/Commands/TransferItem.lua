--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local PersistInventory = require(script.Parent.Parent.PersistInventory)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
    @class TransferItem
    Application command that moves or merges items between two inventory slots.
    @server
]=]
local TransferItem = {}
TransferItem.__index = TransferItem

--[=[
    Create a new TransferItem instance (zero-arg for Registry).
    @within TransferItem
    @return TransferItem
]=]
function TransferItem.new()
	local self = setmetatable({}, TransferItem)
	return self
end

--- Pulls dependencies from the Registry
function TransferItem:Init(registry: any, _name: string)
	self.TransferItemPolicy = registry:Get("TransferItemPolicy")
	self.StackingService = registry:Get("ItemStackingService")
	self.SyncService = registry:Get("InventorySyncService")
	self.PersistenceService = registry:Get("InventoryPersistenceService")
end

--[=[
    Transfer an item between two slots: moves to empty slot, merges stacks, or swaps with occupant.
    @within TransferItem
    @param player Player -- The player whose inventory is modified
    @param userId number -- The player's UserId
    @param fromSlot number -- Source slot index
    @param toSlot number -- Destination slot index
    @return Result<any> -- Ok with a confirmation message; Err if validation fails
]=]
function TransferItem:Execute(player: Player, userId: number, fromSlot: number, toSlot: number): Result.Result<any>
	Ensure(player ~= nil and userId > 0, "InvalidArgument", "Invalid player or userId")

	local ctx = Try(self.TransferItemPolicy:Check(userId, fromSlot, toSlot))
	local playerInventory = ctx.InventoryState
	MentionSuccess("Inventory:TransferItem:Validation", "userId: " .. userId .. " - Validation passed for slot " .. fromSlot .. " -> " .. toSlot)

	local fromSlotData = playerInventory.Slots[fromSlot]
	local toSlotData = playerInventory.Slots[toSlot]

	-- Route transfer based on destination slot state:
	-- (1) Empty dest → simple move; (2) Same item, stackable → merge; (3) Otherwise → swap
	if not toSlotData then
		self:_MoveToEmptySlot(userId, fromSlot, toSlot)
	elseif fromSlotData.ItemId == toSlotData.ItemId and self.StackingService:CanStack(fromSlotData.ItemId, toSlotData.ItemId) then
		self:_MergeStacks(userId, fromSlot, toSlot, fromSlotData, toSlotData, playerInventory)
	else
		self:_SwapSlots(userId, fromSlot, toSlot)
	end

	MentionSuccess("Inventory:TransferItem:SlotManagement", "userId: " .. userId .. " - Transferred slot " .. fromSlot .. " -> " .. toSlot)

	PersistInventory(self.SyncService, self.PersistenceService, player, userId)
	MentionSuccess("Inventory:TransferItem:Persistence", "userId: " .. userId .. " - Inventory persisted successfully")

	return Ok({ Message = "Item transferred successfully" })
end

function TransferItem:_MoveToEmptySlot(userId: number, fromSlot: number, toSlot: number)
	self.SyncService:MoveSlot(userId, fromSlot, toSlot)
	self.SyncService:UpdateMetadata(userId, { LastModified = os.time() })
end

function TransferItem:_SwapSlots(userId: number, fromSlot: number, toSlot: number)
	self.SyncService:SwapSlots(userId, fromSlot, toSlot)
	self.SyncService:UpdateMetadata(userId, { LastModified = os.time() })
end

function TransferItem:_MergeStacks(userId: number, fromSlot: number, toSlot: number, fromSlotData: any, toSlotData: any, playerInventory: any)
	-- Calculate how much can fit in destination before its stack limit is reached
	local availableSpace = self.StackingService:GetAvailableStackSpace(toSlotData)
	local toTransfer = math.min(fromSlotData.Quantity, availableSpace)
	local newFromQty = fromSlotData.Quantity - toTransfer

	-- Add transferred quantity to destination slot
	self.SyncService:UpdateSlotQuantity(userId, toSlot, toSlotData.Quantity + toTransfer)

	-- Remove source slot entirely if all items were transferred; otherwise update its quantity
	if newFromQty <= 0 then
		self.SyncService:SetSlot(userId, fromSlot, nil)
		self.SyncService:UpdateMetadata(userId, {
			UsedSlots = math.max(0, playerInventory.Metadata.UsedSlots - 1),
			LastModified = os.time(),
		})
	else
		self.SyncService:UpdateSlotQuantity(userId, fromSlot, newFromQty)
		self.SyncService:UpdateMetadata(userId, { LastModified = os.time() })
	end
end

return TransferItem
