--!strict

local StructureAIProfiles = {
	StructureAttackAI = {
		ProfileId = "StructureAttackAI",
		DefinitionId = "StructureAttackBehavior",
		TickInterval = 0.2,
		InitialBehaviorId = "StructureIdle",
		InitialNodePath = { "StructureIdle" },
		Blackboard = {},
	},
	StructureExtractAI = {
		ProfileId = "StructureExtractAI",
		DefinitionId = "StructureExtractBehavior",
		TickInterval = 0.5,
		InitialBehaviorId = "StructureIdle",
		InitialNodePath = { "StructureIdle" },
		Blackboard = {},
	},
	StructureStasisAI = {
		ProfileId = "StructureStasisAI",
		DefinitionId = "StructureStasisBehavior",
		TickInterval = 0.25,
		InitialBehaviorId = "StructureIdle",
		InitialNodePath = { "StructureIdle" },
		Blackboard = {},
	},
	StructurePassiveAI = {
		ProfileId = "StructurePassiveAI",
		DefinitionId = "StructureIdleBehavior",
		TickInterval = 1,
		InitialBehaviorId = "StructureIdle",
		InitialNodePath = { "StructureIdle" },
		Blackboard = {},
	},
}

return table.freeze(StructureAIProfiles)
