--!strict

local EnemyAIProfiles = {
	EnemySwarmAI = {
		ProfileId = "EnemySwarmAI",
		DefinitionId = "EnemyTargetOrAdvance",
		TickInterval = 0.15,
		InitialBehaviorId = "EnemyAdvance",
		InitialNodePath = { "EnemyAdvance" },
		Blackboard = {},
		Metadata = {
			Description = "Enemy AI profile for Swarm enemies.",
			Role = "Swarm",
		},
	},

	EnemyTankAI = {
		ProfileId = "EnemyTankAI",
		DefinitionId = "EnemyTargetOrAdvance",
		TickInterval = 0.15,
		InitialBehaviorId = "EnemyAdvance",
		InitialNodePath = { "EnemyAdvance" },
		Blackboard = {},
		Metadata = {
			Description = "Enemy AI profile for Tank enemies.",
			Role = "Tank",
		},
	},
}

return table.freeze(EnemyAIProfiles)
