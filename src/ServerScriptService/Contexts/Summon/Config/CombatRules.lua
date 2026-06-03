--!strict

local CombatRules = {
	MovementPresentation = {
		{
			RuleId = "Summon.MovementPresentation",
			Query = { FeatureName = "Summon", Keys = { "DroneTag" } },
			TargetEntityId = { FeatureName = "Summon", Key = "TargetEnemyId" },
		},
	},
}

return table.freeze(CombatRules)
