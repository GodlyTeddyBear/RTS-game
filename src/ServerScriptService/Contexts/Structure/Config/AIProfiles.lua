--!strict

local StructureAIProfiles = {
	StructureAttackAI = {
		ProfileId = "StructureAttackAI",
		DefinitionId = "OperationalAttackOrIdle",
		TickInterval = 0.2,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
	StructureExtractAI = {
		ProfileId = "StructureExtractAI",
		DefinitionId = "OperationalExtractOrIdle",
		TickInterval = 0.5,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
	StructureStasisAI = {
		ProfileId = "StructureStasisAI",
		DefinitionId = "OperationalStasisOrIdle",
		TickInterval = 0.25,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
	StructurePassiveAI = {
		ProfileId = "StructurePassiveAI",
		DefinitionId = "IdleOnly",
		TickInterval = 1,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
	},
}

return table.freeze(StructureAIProfiles)
