--!strict

--[[
	Role unlock definitions. Owning context: Worker.
]]

return {

	Lumberjack = {
		TargetId = "Lumberjack",
		Category = "Role",
		DisplayName = "Lumberjack",
		Description = "Chop trees for wood and timber.",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	Miner = {
		TargetId = "Miner",
		Category = "Role",
		DisplayName = "Miner",
		Description = "Mine ore from the depths.",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	Forge = {
		TargetId = "Forge",
		Category = "Role",
		DisplayName = "Blacksmith",
		Description = "Smelt ore into weapons and tools.",
		Conditions = { Chapter = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Brewery = {
		TargetId = "Brewery",
		Category = "Role",
		DisplayName = "Brewer",
		Description = "Craft potions and brews.",
		Conditions = { Chapter = 3 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Herbalist = {
		TargetId = "Herbalist",
		Category = "Role",
		DisplayName = "Herbalist",
		Description = "Gather herbs and cultivate plants.",
		Conditions = { Chapter = 2, CommissionTier = 2, QuestsCompleted = 5 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Tailor = {
		TargetId = "Tailor",
		Category = "Role",
		DisplayName = "Tailor",
		Description = "Craft clothing and armor from raw materials.",
		Conditions = { Chapter = 3, CommissionTier = 3, Gold = 500 },
		AutoUnlock = false,
		StartsUnlocked = false,
	},

	Farmer = {
		TargetId = "Farmer",
		Category = "Role",
		DisplayName = "Farmer",
		Description = "Tend crops for food and trade.",
		Conditions = { Chapter = 3, CommissionTier = 3, QuestsCompleted = 8, Gold = 300 },
		AutoUnlock = false,
		StartsUnlocked = false,
	},

}
