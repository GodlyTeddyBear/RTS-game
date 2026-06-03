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
				MovingState = "Walk",
				IdleState = "Idle",
			},
			Attack = {
				PathState = { FeatureName = "Enemy", Key = "PathState" },
				Speed = { FeatureName = "Enemy", Key = "CurrentMoveSpeed" },
				Target = {},
				Animation = {
					FeatureName = "Enemy",
					StateKey = "AnimationState",
					LoopingKey = "AnimationLooping",
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
		},
	},
}

return table.freeze(CombatRules)
