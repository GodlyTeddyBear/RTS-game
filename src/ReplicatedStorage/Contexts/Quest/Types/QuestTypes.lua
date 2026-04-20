--!strict

export type TExpeditionStatus = "Preparing" | "InCombat" | "Victory" | "Defeat" | "Fled"

export type TExpeditionPartyMember = {
	AdventurerId: string,
	AdventurerType: string,
}

export type TExpeditionLootItem = {
	ItemId: string,
	Quantity: number,
}

export type TExpeditionState = {
	ExpeditionId: string,
	ZoneId: string,
	Status: TExpeditionStatus,
	Party: { TExpeditionPartyMember },
	StartedAt: number,
	CompletedAt: number?,
	Loot: { TExpeditionLootItem }?,
	GoldEarned: number?,
	DeadAdventurerIds: { string }?,
}

export type TQuestState = {
	ActiveExpedition: TExpeditionState?,
	CompletedCount: number,
}

return {}
