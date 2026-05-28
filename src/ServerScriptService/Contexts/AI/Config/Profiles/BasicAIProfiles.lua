--!strict

local BasicAIProfiles = {
	IdleAI = {
		ProfileId = "IdleAI",
		DefinitionId = "IdleOnly",
		TickInterval = 1,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
		Metadata = {
			Description = "Template AI profile that only idles.",
		},
	},

	TargetAttackAI = {
		ProfileId = "TargetAttackAI",
		DefinitionId = "AttackIfTarget",
		TickInterval = 0.25,
		InitialBehaviorId = "Idle",
		InitialNodePath = { "Idle" },
		Blackboard = {},
		Metadata = {
			Description = "Template AI profile that attacks TargetEntity facts and idles otherwise.",
		},
	},
}

return table.freeze(BasicAIProfiles)
