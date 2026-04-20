--!strict

--[[
	Rank Configuration

	Single source of truth for worker guild ranks.

	Ranks: Apprentice (default) -> Journeyman (level 15) -> Master (level 30)

	Workers are promoted automatically when their level crosses a threshold.
	No materials, no exams — just level-based auto-promotion.
]]

export type TRankData = {
	RankId: string,
	DisplayName: string,
	Order: number,            -- For comparison: Apprentice=1, Journeyman=2, Master=3
	LevelThreshold: number,   -- Minimum worker level required for this rank
	ProductionBonus: number,  -- Additive production speed bonus (0.25 = +25%)
	BadgeColor: Color3,
}

local RankOrder = { "Apprentice", "Journeyman", "Master" }

local Ranks: { [string]: TRankData } = table.freeze({
	Apprentice = {
		RankId = "Apprentice",
		DisplayName = "Apprentice",
		Order = 1,
		LevelThreshold = 1,
		ProductionBonus = 0.0,
		BadgeColor = Color3.fromRGB(160, 160, 160),  -- Gray
	},
	Journeyman = {
		RankId = "Journeyman",
		DisplayName = "Journeyman",
		Order = 2,
		LevelThreshold = 15,
		ProductionBonus = 0.25,
		BadgeColor = Color3.fromRGB(70, 130, 200),  -- Blue
	},
	Master = {
		RankId = "Master",
		DisplayName = "Master",
		Order = 3,
		LevelThreshold = 30,
		ProductionBonus = 0.55,
		BadgeColor = Color3.fromRGB(218, 165, 32),  -- Gold
	},
})

return table.freeze({
	Ranks = Ranks,
	RankOrder = RankOrder,
})
