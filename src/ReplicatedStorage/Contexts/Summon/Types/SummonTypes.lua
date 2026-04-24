--!strict

--[=[
	@class SummonTypes
	Shared summon type contracts used by server summon systems.
	@server
	@client
]=]
local SummonTypes = {}

export type SwarmTuning = {
	summonCount: number,
	lifetime: number,
	maxConcurrentDronesPerPlayer: number,
	moveSpeed: number,
	acquireRange: number,
	attackRange: number,
	attackInterval: number,
	damagePerHit: number,
}

return table.freeze(SummonTypes)
