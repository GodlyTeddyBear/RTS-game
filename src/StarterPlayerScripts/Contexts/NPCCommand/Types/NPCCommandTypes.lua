--!strict

export type TCommandType = "ATTACK" | "MOVE" | "HOLD" | "SKILLS" | "CONSUMABLES"

export type TStance = "IDLE" | "ATTACKING" | "MOVING" | "HOLDING"

export type TNPCEntry = {
	NPCId: string,
	DisplayName: string,
	Class: string,
	HPPercent: number,
	Mode: "AUTO" | "MANUAL",
	Stance: TStance,
	TargetName: string?,
	AccentColor: Color3,
	LayoutOrder: number,
	isSelected: boolean,
}

export type TOrderEntry = {
	NPCType: string,
	CommandType: string,
	TimestampLabel: string,
	LayoutOrder: number,
}

export type TRecentOrder = {
	NPCType: string,
	CommandType: string,
	IssuedAt: number,
}

export type TConsumableEntry = {
	SlotIndex: number,
	ItemId: string,
	ItemName: string,
	Quantity: number,
	HealAmount: number?,
	IsHealing: boolean,
	NameAbbr: string,
	LayoutOrder: number,
}

return {}
