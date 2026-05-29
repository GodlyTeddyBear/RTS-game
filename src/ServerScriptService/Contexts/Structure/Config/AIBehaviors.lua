--!strict

local StructureAIBehaviors = {
	StructureAttackOrIdle = {
		DefinitionId = "StructureAttackOrIdle",
		Definition = {
			Priority = {
				{
					Sequence = {
						"CanAttack",
						"Attack",
					},
				},
				"Idle",
			},
		},
	},

	StructureExtractOrIdle = {
		DefinitionId = "StructureExtractOrIdle",
		Definition = {
			Priority = {
				{
					Sequence = {
						"IsOperational",
						"Extract",
					},
				},
				"Idle",
			},
		},
	},

	StructureStasisOrIdle = {
		DefinitionId = "StructureStasisOrIdle",
		Definition = {
			Priority = {
				{
					Sequence = {
						"IsOperational",
						"Stasis",
					},
				},
				"Idle",
			},
		},
	},

	StructurePassiveIdle = {
		DefinitionId = "StructurePassiveIdle",
		Definition = "Idle",
	},
}

return table.freeze(StructureAIBehaviors)
