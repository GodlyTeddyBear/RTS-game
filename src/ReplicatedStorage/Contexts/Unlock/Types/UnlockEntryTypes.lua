--!strict

--[[
	Shared contract for unlock entries merged into `UnlockConfig`.

	Owning contexts export plain tables `{ [targetId]: TUnlockEntry }` that
	UnlockConfig aggregates. Do not duplicate the same `TargetId` across exports.

	Ownership (source of truth for metadata):
	  - Inventory — ShopItem (item id = TargetId); co-located on ItemData.Unlock
	  - Building — Building (TargetId = Zone_BuildingType)
	  - Worker — Role, Ore, Tree (worker assignment / resource targets)
	  - Quest — Zone (exploration zones; aligns with ZoneConfig)
	  - Commission — CommissionTier (commission progression gates)

	Unlock context evaluates and persists unlock state only; it does not own
	definition rows after migration.
]]

export type TUnlockConditions = {
	Chapter: number?,
	CommissionTier: number?,
	QuestsCompleted: number?,
	Gold: number?,
	WorkerCount: number?,
	SmelterPlaced: boolean?,
	Ch2FirstVictory: boolean?,
}

export type TUnlockEntry = {
	TargetId: string,
	Category: string,
	DisplayName: string,
	Description: string,
	Conditions: TUnlockConditions,
	AutoUnlock: boolean,
	StartsUnlocked: boolean,
}

return {}
