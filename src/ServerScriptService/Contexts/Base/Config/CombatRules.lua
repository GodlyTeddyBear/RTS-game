--!strict

local CombatRules = {
	HealthDepleted = {
		{
			OutcomeId = "RunFailure",
			VictimKind = "Base",
			DestroyVictim = false,
			EmitRequest = {
				ArchetypeName = "Run.FailureRequest",
				ComponentKey = "FailureRequest",
				Payload = {
					Reason = "BaseDestroyed",
					EmitEvent = "BaseDestroyed",
				},
			},
		},
	},
}

return table.freeze(CombatRules)
