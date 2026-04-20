--!strict

--[[
    NPC type definitions for the NPC context.
    Shared between server and client.
]]

local CombatComponentTypes = require(script.Parent.CombatComponentTypes)

export type THealthComponent = CombatComponentTypes.THealthComponent
export type TStatsComponent = CombatComponentTypes.TStatsComponent
export type TTeamComponent = CombatComponentTypes.TTeamComponent
export type TNPCIdentityComponent = CombatComponentTypes.TNPCIdentityComponent

-- Spawn parameters for creating an adventurer NPC
export type TAdventurerSpawnParams = {
	AdventurerId: string,
	AdventurerType: string,
	EffectiveHP: number,
	EffectiveATK: number,
	EffectiveDEF: number,
	SpawnPosition: Vector3,
}

-- Spawn parameters for creating an enemy NPC
export type TEnemySpawnParams = {
	EnemyId: string,
	EnemyType: string,
	BaseHP: number,
	BaseATK: number,
	BaseDEF: number,
	SpawnPosition: Vector3,
}

-- Combat NPC state for client sync
export type TCombatNPCState = {
	NPCId: string,
	NPCType: string,
	Team: "Adventurer" | "Enemy",
	HP: number,
	MaxHP: number,
	State: string,
	X: number,
	Y: number,
	Z: number,
}

-- Full combat state synced to client per user
export type TCombatSyncState = {
	NPCs: { [string]: TCombatNPCState },
	CurrentWave: number,
	TotalWaves: number,
	Status: string, -- "Active" | "WaveTransition" | "Victory" | "Defeat"
}

return {}
