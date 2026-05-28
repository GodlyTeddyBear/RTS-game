--!strict

local BasicBehaviors = {
	IdleOnly = {
		DefinitionId = "IdleOnly",
		Definition = "Idle",
		Metadata = {
			Description = "Template behavior that always emits idle intent.",
		},
	},

	AttackIfTarget = {
		DefinitionId = "AttackIfTarget",
		Definition = {
			Priority = {
				{
					Sequence = {
						"HasTargetEntity",
						"Attack",
					},
				},
				"Idle",
			},
		},
		Metadata = {
			Description = "Template behavior that attacks a target fact, otherwise idles.",
		},
	},
}

return table.freeze(BasicBehaviors)
