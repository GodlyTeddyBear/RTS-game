--!strict

local UnitAIProfiles = {
	UnitBuilderAI = {
		ProfileId = "UnitBuilderAI",
		DefinitionId = "UnitBuilderBehavior",
		TickInterval = 0.15,
		InitialBehaviorId = "UnitIdle",
		InitialNodePath = { "UnitIdle" },
		Blackboard = {},
		Metadata = {
			Description = "Unit AI profile for manual movement, builder construction, and idle fallback.",
			RuntimeProfileId = "Builder",
		},
	},
}

return table.freeze(UnitAIProfiles)
