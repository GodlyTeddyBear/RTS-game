--!strict

local SummonAIProfiles = {
	SummonSwarmDroneAI = {
		ProfileId = "SummonSwarmDroneAI",
		DefinitionId = "EngageEnemyOrIdle",
		TickInterval = 0.1,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
		Metadata = {
			Description = "Summon AI profile for swarm drones.",
			Kind = "SwarmDrone",
		},
	},
}

return table.freeze(SummonAIProfiles)
