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
					ChannelId = "FullBody",
					State = "Attack",
				},
				TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
			},
			ActionPresentation = {
				Extract = {
					Animation = {
						ChannelId = "LoopingAction",
						State = "Extract",
					},
				},
				Stasis = {
					Animation = {
						ChannelId = "LoopingAction",
						State = "Stasis",
					},
					TargetEntityId = { FeatureName = "Structure", Key = "TargetEnemyId" },
				},
				Idle = {
					Animation = {
						ChannelId = "LoopingAction",
						State = "Idle",
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
