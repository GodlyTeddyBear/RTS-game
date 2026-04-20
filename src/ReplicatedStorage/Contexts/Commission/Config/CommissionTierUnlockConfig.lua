--!strict

--[[
	Commission tier progression unlocks. Owning context: Commission.
]]

return {

	CommissionTier2 = {
		TargetId = "CommissionTier2",
		Category = "CommissionTier",
		DisplayName = "Journeyman Commissions",
		Description = "Access tier 2 commissions.",
		Conditions = { CommissionTier = 1 },
		AutoUnlock = true,
		StartsUnlocked = true,
	},

	CommissionTier3 = {
		TargetId = "CommissionTier3",
		Category = "CommissionTier",
		DisplayName = "Expert Commissions",
		Description = "Access tier 3 commissions.",
		Conditions = { Chapter = 2, CommissionTier = 2 },
		AutoUnlock = true,
		StartsUnlocked = false,
	},

}
