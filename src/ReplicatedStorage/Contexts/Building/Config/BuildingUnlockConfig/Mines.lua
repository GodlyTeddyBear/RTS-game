--!strict

return {

	Mines_MineShaft = {
		TargetId = "Mines_MineShaft",
		Category = "Building",
		DisplayName = "Mine Shaft",
		Description = "Digs deeper into the earth.",
		Conditions = {},
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	Mines_OreProcessingTable = {
		TargetId = "Mines_OreProcessingTable",
		Category = "Building",
		DisplayName = "Ore Processing Table",
		Description = "Refines raw ore into usable form.",
		Conditions = { Chapter = 2, CommissionTier = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

}
