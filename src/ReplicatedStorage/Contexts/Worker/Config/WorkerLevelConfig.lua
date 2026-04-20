--!strict

-- Configuration for worker leveling progression
-- Controls XP requirements and level caps

return table.freeze({
	XPRequirementBase = 100, -- Level 1 → 2 requires 100 XP
	XPRequirementGrowth = 1.2, -- 20% increase per level (exponential scaling)
	MaxLevel = 50, -- Cap at level 50
})
