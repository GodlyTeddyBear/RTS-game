--!strict

--[[
	Tree harvest unlock targets. Owning context: Worker.
]]

return {

	Oak = {
		TargetId = "Oak",
		Category = "Tree",
		DisplayName = "Oak Tree",
		Description = "A sturdy common tree.",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	Pine = {
		TargetId = "Pine",
		Category = "Tree",
		DisplayName = "Pine Tree",
		Description = "Tall conifers yielding quality timber.",
		Conditions = { WorkerCount = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Birch = {
		TargetId = "Birch",
		Category = "Tree",
		DisplayName = "Birch Tree",
		Description = "Slender trees with fine-grained wood.",
		Conditions = { Chapter = 2, CommissionTier = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

	Mahogany = {
		TargetId = "Mahogany",
		Category = "Tree",
		DisplayName = "Mahogany Tree",
		Description = "Dense hardwood prized by craftsmen.",
		Conditions = { Chapter = 3, CommissionTier = 3, QuestsCompleted = 5, Gold = 400 },
		AutoUnlock = false,
		StartsUnlocked = false,
	},

	Willow = {
		TargetId = "Willow",
		Category = "Tree",
		DisplayName = "Willow Tree",
		Description = "Supple wood used in weaving and fletching.",
		Conditions = { Chapter = 3, CommissionTier = 3, QuestsCompleted = 3 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

}
