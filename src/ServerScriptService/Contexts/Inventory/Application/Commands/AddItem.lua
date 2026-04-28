--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try
local Ensure = Result.Ensure

local AddItem = {}
AddItem.__index = AddItem
setmetatable(AddItem, BaseCommand)

function AddItem.new()
	local self = BaseCommand.new("Inventory", "AddItem")
	return setmetatable(self, AddItem)
end

function AddItem:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		AddItemPolicy = "AddItemPolicy",
		SlotManagementService = "SlotManagementService",
		SyncService = "InventorySyncService",
	})
end

function AddItem:Execute(userId: number, itemId: string, quantity: number): Result.Result<any>
	Ensure(userId > 0, "InvalidArgument", Errors.INVALID_USER_ID, { userId = userId })

	self.SyncService:EnsureInventory(userId)
	local ctx = Try(self.AddItemPolicy:Check(userId, itemId, quantity))
	local playerInventory = ctx.InventoryState
	local updatedSlots, remaining = self:_StackOntoExistingSlots(playerInventory, itemId, quantity)
	local inventoryCopy = self:_BuildWorkingCopy(playerInventory, updatedSlots)
	local newSlots
	newSlots, remaining = self:_FillNewSlots(inventoryCopy, itemId, remaining)

	local addedQuantity = quantity - remaining
	if addedQuantity <= 0 then
		return Err("InventoryFull", Errors.INVENTORY_FULL, { itemId = itemId, userId = userId })
	end

	self:_ApplyChanges(userId, updatedSlots, newSlots, playerInventory.Metadata.UsedSlots)

	return Ok({
		Message = "Item added successfully",
		AddedQuantity = addedQuantity,
		RemainingQuantity = remaining,
	})
end

function AddItem:_StackOntoExistingSlots(playerInventory: any, itemId: string, quantity: number): ({ [number]: number }, number)
	local itemData = ItemConfig[itemId]
	local maxStack = itemData.MaxStack
	local remaining = quantity
	local updatedSlots: { [number]: number } = {}

	for slotIndex, slot in pairs(playerInventory.Slots) do
		if remaining <= 0 then
			break
		end

		if slot.ItemId ~= itemId or slot.Quantity >= maxStack then
			continue
		end

		local toAdd = math.min(remaining, maxStack - slot.Quantity)
		updatedSlots[slotIndex] = slot.Quantity + toAdd
		remaining -= toAdd
	end

	return updatedSlots, remaining
end

function AddItem:_BuildWorkingCopy(playerInventory: any, updatedSlots: { [number]: number }): any
	local copy = {
		Slots = table.clone(playerInventory.Slots),
		Metadata = table.clone(playerInventory.Metadata),
	}

	for slotIndex, newQuantity in pairs(updatedSlots) do
		copy.Slots[slotIndex] = table.clone(copy.Slots[slotIndex])
		copy.Slots[slotIndex].Quantity = newQuantity
	end

	return copy
end

function AddItem:_FillNewSlots(inventoryCopy: any, itemId: string, remaining: number): ({ [number]: any }, number)
	local itemData = ItemConfig[itemId]
	local maxStack = itemData.MaxStack
	local newSlots: { [number]: any } = {}

	while remaining > 0 do
		local availableSlot = self.SlotManagementService:FindAvailableSlot(inventoryCopy)
		if not availableSlot then
			break
		end

		local toAdd = math.min(remaining, maxStack)
		local slotData = {
			SlotIndex = availableSlot,
			ItemId = itemId,
			Quantity = toAdd,
			Category = itemData.Category,
		}
		newSlots[availableSlot] = slotData
		inventoryCopy.Slots[availableSlot] = slotData
		remaining -= toAdd
	end

	return newSlots, remaining
end

function AddItem:_ApplyChanges(userId: number, updatedSlots: { [number]: number }, newSlots: { [number]: any }, previousUsedSlots: number)
	for slotIndex, newQuantity in pairs(updatedSlots) do
		self.SyncService:UpdateSlotQuantity(userId, slotIndex, newQuantity)
	end

	local newSlotsCount = 0
	for slotIndex, slotData in pairs(newSlots) do
		self.SyncService:SetSlot(userId, slotIndex, slotData)
		newSlotsCount += 1
	end

	self.SyncService:UpdateMetadata(userId, {
		UsedSlots = previousUsedSlots + newSlotsCount,
		LastModified = os.time(),
	})
end

return AddItem
