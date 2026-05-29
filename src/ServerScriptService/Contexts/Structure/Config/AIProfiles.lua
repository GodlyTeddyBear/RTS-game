--!strict

local StructureAIProfiles = {
	StructureAttackAI = {
		ProfileId = "StructureAttackAI",
		DefinitionId = "StructureAttackOrIdle",
		TickInterval = 0.2,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
	StructureExtractAI = {
		ProfileId = "StructureExtractAI",
		DefinitionId = "StructureExtractOrIdle",
		TickInterval = 0.5,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
	StructureStasisAI = {
		ProfileId = "StructureStasisAI",
		DefinitionId = "StructureStasisOrIdle",
		TickInterval = 0.25,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
	StructurePassiveAI = {
		ProfileId = "StructurePassiveAI",
		DefinitionId = "StructurePassiveIdle",
		TickInterval = 1,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
}

return table.freeze(StructureAIProfiles)
