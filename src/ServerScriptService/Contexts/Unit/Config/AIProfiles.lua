--!strict

local UnitAIProfiles = {
	UnitBuilderAI = {
		ProfileId = "UnitBuilderAI",
		DefinitionId = "MoveBuildIdle",
		TickInterval = 0.15,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
		Metadata = {
			Description = "Unit AI profile for manual movement, builder construction, and idle fallback.",
			RuntimeProfileId = "Builder",
		},
	},
}

return table.freeze(UnitAIProfiles)
