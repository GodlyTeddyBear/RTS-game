--!strict

local UnitAIBehaviors = {
	UnitMoveBuildIdle = {
		DefinitionId = "UnitMoveBuildIdle",
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
			Description = "Unit behavior for manual movement, builder construction, and idle fallback.",
		},
	},
}

return table.freeze(UnitAIBehaviors)
