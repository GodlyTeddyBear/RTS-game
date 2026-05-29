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

	AttackOrAdvance = {
		DefinitionId = "AttackOrAdvance",
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
			Description = "Attacks a resolved target when available, otherwise advances toward a goal.",
		},
	},

	OperationalAttackOrIdle = {
		DefinitionId = "OperationalAttackOrIdle",
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
		Metadata = {
			Description = "Operational actor attacks a target entity, otherwise idles.",
		},
	},

	OperationalExtractOrIdle = {
		DefinitionId = "OperationalExtractOrIdle",
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
		Metadata = {
			Description = "Operational actor emits extraction intent, otherwise idles.",
		},
	},

	OperationalStasisOrIdle = {
		DefinitionId = "OperationalStasisOrIdle",
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
		Metadata = {
			Description = "Operational actor emits stasis intent, otherwise idles.",
		},
	},

	MoveBuildIdle = {
		DefinitionId = "MoveBuildIdle",
		Definition = {
			Priority = {
				{
					Sequence = {
						"HasGoalTarget",
						"ManualMove",
					},
				},
				{
					Sequence = {
						"HasBuildableTarget",
						"BuildStructure",
					},
				},
				"Idle",
			},
		},
		Metadata = {
			Description = "Moves to a manual goal, builds valid targets, otherwise idles.",
		},
	},

	EngageEnemyOrIdle = {
		DefinitionId = "EngageEnemyOrIdle",
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
			Description = "Engages a resolved enemy target, otherwise idles.",
		},
	},
}

return table.freeze(BasicBehaviors)
