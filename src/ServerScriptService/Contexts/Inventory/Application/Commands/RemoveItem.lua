--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

local RemoveItem = {}
RemoveItem.__index = RemoveItem
setmetatable(RemoveItem, BaseCommand)

function RemoveItem.new()
	local self = BaseCommand.new("Inventory", "RemoveItem")
	return setmetatable(self, RemoveItem)
end

function RemoveItem:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		RemoveItemPolicy = "RemoveItemPolicy",
		SyncService = "InventorySyncService",
	})
end

function RemoveItem:Execute(userId: number, slotIndex: number, quantity: number): Result.Result<any>
	Ensure(userId > 0, "InvalidArgument", Errors.INVALID_USER_ID, { userId = userId })

	local ctx = Try(self.RemoveItemPolicy:Check(userId, slotIndex, quantity))
	local playerInventory = ctx.InventoryState
	local slot = ctx.Slot

	local removedQuantity = quantity
	local slotRemoved = false
	if quantity >= slot.Quantity then
		self.SyncService:SetSlot(userId, slotIndex, nil)
		self.SyncService:UpdateMetadata(userId, {
			UsedSlots = math.max(0, playerInventory.Metadata.UsedSlots - 1),
			LastModified = os.time(),
		})
		removedQuantity = slot.Quantity
		slotRemoved = true
	else
		self.SyncService:UpdateSlotQuantity(userId, slotIndex, slot.Quantity - quantity)
		self.SyncService:UpdateMetadata(userId, { LastModified = os.time() })
	end

	return Ok({
		Message = "Item removed successfully",
		RemovedQuantity = removedQuantity,
		SlotRemoved = slotRemoved,
	})
end

return RemoveItem
