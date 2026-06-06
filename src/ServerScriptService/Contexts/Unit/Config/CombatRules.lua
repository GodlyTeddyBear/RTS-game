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
				RevisionKey = "AnimationRevision",
				ActionKey = "AnimationAction",
				ActionOnly = true,
			},
			ActionPresentation = {
				BuildStructure = {
					WhenNotMoving = true,
					Animation = {
						FeatureName = "Unit",
						StateKey = "AnimationState",
						LoopingKey = "AnimationLooping",
						RevisionKey = "AnimationRevision",
						ActionKey = "AnimationAction",
						State = "Build",
						Looping = true,
					},
				},
			},
		},
	},
}

return table.freeze(CombatRules)
