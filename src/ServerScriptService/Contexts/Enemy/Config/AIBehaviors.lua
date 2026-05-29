--!strict

local EnemyAIBehaviors = {
	EnemyAttackOrAdvance = {
		DefinitionId = "EnemyAttackOrAdvance",
		Definition = {
			Priority = {
				{
					Sequence = {
						"HasAttackTarget",
						"Attack",
					},
				},
				"Advance",
			},
		},
		Metadata = {
			Description = "Enemy behavior that attacks a resolved target or advances toward the base.",
		},
	},
}

return table.freeze(EnemyAIBehaviors)
