--!strict

-- Configuration for worker ranks.
-- Rank determines the worker's tier and base stats, independent of their role/occupation.
-- Model selection is driven by the worker's assigned role (see RoleConfig).
-- Rank IDs must match the keys in RankConfig.Ranks.

return table.freeze({
	Apprentice = {
		Rank = "Apprentice",
		BaseProductionRate = 1.0,
		LevelScaling = 0.1, -- +10% speed per level (Level 10 = 1.9x speed)
		XPPerProduction = 10,
		BaseCost = 0,
	},
	Journeyman = {
		Rank = "Journeyman",
		BaseProductionRate = 1.2,
		LevelScaling = 0.12,
		XPPerProduction = 12,
		BaseCost = 0,
	},
	Master = {
		Rank = "Master",
		BaseProductionRate = 1.5,
		LevelScaling = 0.15,
		XPPerProduction = 15,
		BaseCost = 0,
	},
})
