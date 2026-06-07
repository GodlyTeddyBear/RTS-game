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
				ActionOnly = true,
			},
			ActionPresentation = {
				BuildStructure = {
					WhenNotMoving = true,
					Animation = {
						ChannelId = "FullBody",
						State = "Build",
					},
				},
			},
		},
	},
}

return table.freeze(CombatRules)
