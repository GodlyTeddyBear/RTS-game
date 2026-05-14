--!strict

local EquipmentTypes = {}

export type TOwnerKind = "Unit" | "Enemy" | "Structure"
export type TAssetFamily = "Tool" | "Armor" | "Accessory"
export type TSlotId = "Weapon" | "Armor" | "Accessory" | string

export type TOwnerRef = {
	OwnerKind: TOwnerKind,
	OwnerId: string,
}

export type TEquipmentDefinition = {
	ItemId: string,
	SlotId: TSlotId,
	AssetFamily: TAssetFamily,
	AssetId: string,
}

export type TAttachmentHandle = {
	Id: string,
	OwnerModel: Model,
	Instances: { Instance },
}

export type TEquippedItem = {
	ItemId: string,
	SlotId: string,
	AssetFamily: TAssetFamily,
	AssetId: string,
	OwnerKind: TOwnerKind,
	OwnerId: string,
	EquippedAt: number,
	AttachmentId: string,
}

export type TOwnerEquipment = {
	Slots: { [string]: TEquippedItem },
}

export type TEquipmentState = {
	Owners: { [string]: TOwnerEquipment },
}

function EquipmentTypes.BuildOwnerKey(ownerKind: string, ownerId: string): string
	return ownerKind .. ":" .. ownerId
end

return table.freeze(EquipmentTypes)
