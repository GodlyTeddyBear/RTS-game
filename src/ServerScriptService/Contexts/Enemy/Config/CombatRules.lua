--!strict

local CombatRules = {
	MovementPresentation = {
		{
			RuleId = "Enemy.MovementPresentation",
			Query = { FeatureName = "Enemy", Keys = { "AliveTag", "PathState" } },
			PathState = { FeatureName = "Enemy", Key = "PathState" },
			Speed = { FeatureName = "Enemy", Key = "CurrentMoveSpeed" },
			Animation = {
				FeatureName = "Enemy",
				StateKey = "AnimationState",
				LoopingKey = "AnimationLooping",
				RevisionKey = "AnimationRevision",
				ActionKey = "AnimationAction",
				ActionOnly = true,
			},
			Attack = {
				PathState = { FeatureName = "Enemy", Key = "PathState" },
				Speed = { FeatureName = "Enemy", Key = "CurrentMoveSpeed" },
				Target = {},
				Animation = {
					FeatureName = "Enemy",
					StateKey = "AnimationState",
					LoopingKey = "AnimationLooping",
					RevisionKey = "AnimationRevision",
					ActionKey = "AnimationAction",
					State = "Attack",
					Looping = false,
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
