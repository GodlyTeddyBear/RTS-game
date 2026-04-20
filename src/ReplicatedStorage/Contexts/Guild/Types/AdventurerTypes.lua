--!strict

export type TEquipmentSlot = {
	ItemId: string,
	SlotType: string,
}

export type TAdventurer = {
	Id: string,
	Type: string,
	BaseHP: number,
	BaseATK: number,
	BaseDEF: number,
	Equipment: {
		Weapon: TEquipmentSlot?,
		Armor: TEquipmentSlot?,
		Accessory: TEquipmentSlot?,
	},
	HiredAt: number,
	IsOnExpedition: boolean?,
}

return {}
