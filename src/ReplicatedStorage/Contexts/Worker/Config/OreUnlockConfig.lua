--!strict

--[[
	Mineable ore unlock targets. Owning context: Worker.
]]

return {

	Stone = {
		TargetId = "Stone",
		Category = "Ore",
		DisplayName = "Stone",
		Description = "The most basic mineable material.",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	Iron = {
		TargetId = "Iron",
		Category = "Ore",
		DisplayName = "Iron Ore",
		Description = "Common metal ore for basic smithing.",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	Copper = {
		TargetId = "Copper",
		Category = "Ore",
		DisplayName = "Copper Ore",
		Description = "Soft metal used in crafting and trade.",
		Conditions = { WorkerCount = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Coal = {
		TargetId = "Coal",
		Category = "Ore",
		DisplayName = "Coal",
		Description = "Fuel for the forge.",
		Conditions = { Chapter = 2, CommissionTier = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Gold = {
		TargetId = "Gold",
		Category = "Ore",
		DisplayName = "Gold Ore",
		Description = "Precious metal worth a fortune.",
		Conditions = { Chapter = 3, CommissionTier = 3, QuestsCompleted = 5 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Crystal = {
		TargetId = "Crystal",
		Category = "Ore",
		DisplayName = "Crystal",
		Description = "Rare crystals of immense value.",
		Conditions = { Chapter = 3, CommissionTier = 4, QuestsCompleted = 10, Gold = 1000 },
		AutoUnlock = false,
		StartsUnlocked = false,
	},

	Herb = {
		TargetId = "Herb",
		Category = "Ore",
		DisplayName = "Herb",
		Description = "Medicinal herbs found underground.",
		Conditions = { Chapter = 2, CommissionTier = 2, QuestsCompleted = 3 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Silk = {
		TargetId = "Silk",
		Category = "Ore",
		DisplayName = "Silk",
		Description = "Rare fibrous material spun underground.",
		Conditions = { Chapter = 3, CommissionTier = 3, Gold = 600 },
		AutoUnlock = false,
		StartsUnlocked = false,
	},

}
