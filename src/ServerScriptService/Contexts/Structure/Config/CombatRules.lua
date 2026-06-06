--!strict

local CombatRules = {
	MovementPresentation = {
		{
			RuleId = "Structure.Presentation",
			Query = {
				Keys = {
					{ Key = "OperationalTag", FeatureName = "Structure" },
				},
			},
			TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
			Attack = {
				Target = { TargetKind = "Enemy" },
				Animation = {
					FeatureName = "Structure",
					StateKey = "AnimationState",
					LoopingKey = "AnimationLooping",
					RevisionKey = "AnimationRevision",
					ActionKey = "AnimationAction",
					State = "Attack",
					Looping = false,
				},
				TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
			},
			ActionPresentation = {
				Extract = {
					Animation = {
						FeatureName = "Structure",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						RevisionKey = "AnimationRevision",
						ActionKey = "AnimationAction",
						State = "Extract",
						Looping = true,
					},
				},
				Stasis = {
					Animation = {
						FeatureName = "Structure",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						RevisionKey = "AnimationRevision",
						ActionKey = "AnimationAction",
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
						RevisionKey = "AnimationRevision",
						ActionKey = "AnimationAction",
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
			DestroyVictim = true,
		},
	},
}

return table.freeze(CombatRules)
