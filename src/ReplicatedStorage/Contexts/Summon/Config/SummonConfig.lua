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
	summonCount = 5,
	lifetime = 20,
	maxConcurrentDronesPerPlayer = 10,
	moveSpeed = 26,
	acquireRange = 40,
	attackRange = 6,
	attackInterval = 0.6,
	damagePerHit = 6,
} :: SwarmTuning)

return table.freeze(SummonConfig)
