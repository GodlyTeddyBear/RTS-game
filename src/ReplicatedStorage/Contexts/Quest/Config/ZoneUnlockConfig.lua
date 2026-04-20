--!strict

--[[
	Zone exploration unlocks. Owning context: Quest (aligns with ZoneConfig).
]]

return {

	GoblinCave = {
		TargetId = "GoblinCave",
		Category = "Zone",
		DisplayName = "Goblin Cave",
		Description = "A dank cave crawling with goblins.",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	OrcFortress = {
		TargetId = "OrcFortress",
		Category = "Zone",
		DisplayName = "Orc Fortress",
		Description = "A fortified stronghold overrun by orcs.",
		Conditions = { Chapter = 2, QuestsCompleted = 3, CommissionTier = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	TrollDen = {
		TargetId = "TrollDen",
		Category = "Zone",
		DisplayName = "Troll Den",
		Description = "Deep caverns where ancient trolls dwell.",
		Conditions = { Chapter = 3, QuestsCompleted = 8, CommissionTier = 3 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

}
