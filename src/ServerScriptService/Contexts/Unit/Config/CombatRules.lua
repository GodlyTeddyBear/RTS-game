--!strict

local CombatRules = {
	MovementPresentation = {
		{
			RuleId = "Unit.MovementPresentation",
			Query = { FeatureName = "Unit", Keys = { "PathState" } },
			PathState = {
				FeatureName = "Unit",
				Key = "PathState",
				PreserveKeys = {
					"RequestedGoalPosition",
					"GoalRevision",
					"FailedGoalRevision",
				},
			},
			Animation = {
				FeatureName = "Unit",
				StateKey = "AnimationState",
				LoopingKey = "AnimationLooping",
				MovingState = "Walk",
				IdleState = "Idle",
			},
			ActionPresentation = {
				BuildStructure = {
					WhenNotMoving = true,
					Animation = {
						FeatureName = "Unit",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						State = "Build",
						Looping = true,
					},
				},
			},
		},
	},
}

return table.freeze(CombatRules)
