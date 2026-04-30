--!strict

--[=[
	@class SummonTypes
	Shared summon type contracts used by server summon systems.
	@server
	@client
]=]
local SummonTypes = {}

export type SwarmTuning = {
	SummonCount: number,
	Lifetime: number,
	MaxConcurrentDronesPerPlayer: number,
	MoveSpeed: number,
	AcquireRange: number,
	AttackRange: number,
	AttackInterval: number,
	DamagePerHit: number,
}

return table.freeze(SummonTypes)
