--!strict

local CombatRules = {
	MovementPresentation = {
		{
			RuleId = "Enemy.MovementPresentation",
			Query = { FeatureName = "Enemy", Keys = { "AliveTag", "PathState" } },
			PathState = { FeatureName = "Enemy", Key = "PathState" },
			Speed = { FeatureName = "Enemy", Key = "CurrentMoveSpeed" },
			Animation = {
				ActionOnly = true,
			},
			Attack = {
				PathState = { FeatureName = "Enemy", Key = "PathState" },
				Speed = { FeatureName = "Enemy", Key = "CurrentMoveSpeed" },
				Target = {},
				Animation = {
					ChannelId = "FullBody",
					State = "Attack",
				},
			},
		},
	},
	GoalReached = {
		{
			RuleId = "Enemy.AdvanceGoalReached",
			OutcomeId = "EnemyGoalReached",
			Query = { FeatureName = "Enemy", Keys = { "AliveTag" } },
			ActionId = "Advance",
		},
	},
	HealthDepleted = {
		{
			OutcomeId = "EnemyDeath",
			VictimKind = "Enemy",
			DestroyVictim = true,
			EmitRequest = {
				ArchetypeName = "Enemy.DeathEventRequest",
				ComponentKey = "DeathEventRequest",
				FeatureName = "Enemy",
			},
		},
	},
}

return table.freeze(CombatRules)
