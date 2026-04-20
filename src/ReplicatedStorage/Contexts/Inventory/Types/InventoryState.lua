--!strict
local ItemId = require(script.Parent.ItemId)
local Category = require(script.Parent.Category)

export type TInventorySlot = {
	SlotIndex: number,
	ItemId: ItemId.ItemId,
	Quantity: number,
	Category: Category.Category,
}

export type TInventoryMetadata = {
	TotalSlots: number,
	UsedSlots: number,
	LastModified: number,
}

export type TInventoryState = {
	Slots: { [number]: TInventorySlot },
	Metadata: TInventoryMetadata,
}

return {}
