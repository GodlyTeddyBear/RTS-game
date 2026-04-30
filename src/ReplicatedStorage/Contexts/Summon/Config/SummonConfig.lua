--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SummonTypes = require(ReplicatedStorage.Contexts.Summon.Types.SummonTypes)

type SwarmTuning = SummonTypes.SwarmTuning

--[=[
	@class SummonConfig
	Shared tuning values for summon runtime behavior.
	@server
	@client
]=]
local SummonConfig = {}

SummonConfig.SWARM_DRONES = table.freeze({
	SummonCount = 5,
	Lifetime = 20,
	MaxConcurrentDronesPerPlayer = 10,
	MoveSpeed = 26,
	AcquireRange = 40,
	AttackRange = 6,
	AttackInterval = 0.6,
	DamagePerHit = 6,
} :: SwarmTuning)

return table.freeze(SummonConfig)
