--!strict

--[[
	UnlockTypes — Shared type definitions for the Unlock bounded context.
]]

-- Per-player unlock state: maps targetId -> true for all unlocked items.
-- Absence of a key means the item is locked (unless StartsUnlocked in config).
export type TUnlockState = { [string]: boolean }

-- Snapshot of a player's relevant progression state used for condition evaluation.
export type TConditionSnapshot = {
	CommissionTier: number,
	QuestsCompleted: number,
	Gold: number,
	WorkerCount: number,
	Chapter: number,
	SmelterPlaced: boolean,
	Ch2FirstVictory: boolean,
}

return {}
