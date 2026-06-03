--!strict

local CombatRules = {
	MovementPresentation = {
		{
			RuleId = "Structure.AttackPresentation",
			Query = {
				Keys = {
					{ Key = "OperationalTag", FeatureName = "Structure" },
					{ Key = "AttackState", FeatureName = "Combat" },
					{ Key = "ActionState", FeatureName = "AI" },
				},
			},
			Attack = {
				Target = { TargetKind = "Enemy" },
				Animation = {
					FeatureName = "Structure",
					StateKey = "AnimationState",
					LoopingKey = "AnimationLooping",
					State = "Attack",
					Looping = false,
				},
				TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
			},
		},
		{
			RuleId = "Structure.ExtractPresentation",
			Query = {
				Keys = {
					{ Key = "OperationalTag", FeatureName = "Structure" },
					{ Key = "ExtractState", FeatureName = "Structure" },
					{ Key = "ActionState", FeatureName = "AI" },
				},
			},
			ActionPresentation = {
				Extract = {
					Animation = {
						FeatureName = "Structure",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						State = "Extract",
						Looping = true,
					},
				},
				Idle = {
					Animation = {
						FeatureName = "Structure",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						State = "Idle",
						Looping = true,
					},
				},
			},
		},
		{
			RuleId = "Structure.StasisPresentation",
			Query = {
				Keys = {
					{ Key = "OperationalTag", FeatureName = "Structure" },
					{ Key = "StatusAuraState", FeatureName = "Combat" },
					{ Key = "ActionState", FeatureName = "AI" },
				},
			},
			ActionPresentation = {
				Stasis = {
					Animation = {
						FeatureName = "Structure",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						State = "Stasis",
						Looping = true,
					},
					TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
				},
				Idle = {
					Animation = {
						FeatureName = "Structure",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						State = "Idle",
						Looping = true,
					},
					TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
				},
			},
		},
	},
	HealthDepleted = {
		{
			OutcomeId = "StructureDeath",
			VictimKind = "Structure",
		},
	},
}

return table.freeze(CombatRules)
