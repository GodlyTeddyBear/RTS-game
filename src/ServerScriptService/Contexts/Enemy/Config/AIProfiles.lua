--!strict

local EnemyAIProfiles = {
	EnemySwarmAI = {
		ProfileId = "EnemySwarmAI",
		DefinitionId = "AttackOrAdvance",
		TickInterval = 0.15,
		InitialBehaviorId = "Advance",
		InitialNodePath = { "Advance" },
		Blackboard = {},
		Metadata = {
			Description = "Enemy AI profile for Swarm enemies.",
			Role = "Swarm",
		},
	},

	EnemyTankAI = {
		ProfileId = "EnemyTankAI",
		DefinitionId = "AttackOrAdvance",
		TickInterval = 0.15,
		InitialBehaviorId = "Advance",
		InitialNodePath = { "Advance" },
		Blackboard = {},
		Metadata = {
			Description = "Enemy AI profile for Tank enemies.",
			Role = "Tank",
		},
	},
}

return table.freeze(EnemyAIProfiles)
