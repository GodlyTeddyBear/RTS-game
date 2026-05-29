--!strict

local SummonAIProfiles = {
	SummonSwarmDroneAI = {
		ProfileId = "SummonSwarmDroneAI",
		DefinitionId = "SummonSwarmDroneBehavior",
		TickInterval = 0.1,
		InitialBehaviorId = "SummonIdle",
		InitialNodePath = { "SummonIdle" },
		Blackboard = {},
		Metadata = {
			Description = "Summon AI profile for swarm drones.",
			Kind = "SwarmDrone",
		},
	},
}

return table.freeze(SummonAIProfiles)
