--!strict

local SummonAIBehaviors = {
	SummonEngageEnemyOrIdle = {
		DefinitionId = "SummonEngageEnemyOrIdle",
		Definition = {
			Priority = {
				{
					Sequence = {
						"HasEnemyTarget",
						"EngageEnemy",
					},
				},
				"Idle",
			},
		},
		Metadata = {
			Description = "Summon behavior for swarm drones that engage enemies or idle.",
		},
	},
}

return table.freeze(SummonAIBehaviors)
