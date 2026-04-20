--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local AdventurerTypes = require(ReplicatedStorage.Contexts.Guild.Types.AdventurerTypes)

type TAdventurer = AdventurerTypes.TAdventurer

--[=[
	@class StatCalculator
	Pure domain service for computing effective adventurer stats.
	Calculates base stats + equipment bonuses without side effects.
	@server
]=]

--[=[
	@interface TEffectiveStats
	@within StatCalculator
	.HP number -- Effective hit points
	.ATK number -- Effective attack damage
	.DEF number -- Effective defense value
]=]
export type TEffectiveStats = {
	HP: number,
	ATK: number,
	DEF: number,
}

local StatCalculator = {}
StatCalculator.__index = StatCalculator

export type TStatCalculator = typeof(setmetatable({}, StatCalculator))

function StatCalculator.new(): TStatCalculator
	local self = setmetatable({}, StatCalculator)
	return self
end

--[=[
	Calculate effective stats for an adventurer by summing base stats + equipment bonuses.
	@within StatCalculator
	@param adventurer TAdventurer -- The adventurer to calculate stats for
	@return TEffectiveStats -- Effective HP, ATK, and DEF
]=]
function StatCalculator:CalculateEffectiveStats(adventurer: TAdventurer): TEffectiveStats
	local hp = adventurer.BaseHP
	local atk = adventurer.BaseATK
	local def = adventurer.BaseDEF

	-- Iterate through equipped items and accumulate stat bonuses
	if adventurer.Equipment then
		for _, slot in pairs(adventurer.Equipment) do
			if slot and slot.ItemId then
				local itemData = ItemConfig[slot.ItemId]
				if itemData and itemData.stats then
					atk = atk + (itemData.stats.STR or 0)
					def = def + (itemData.stats.DEF or 0)
				end
			end
		end
	end

	return table.freeze({
		HP = hp,
		ATK = atk,
		DEF = def,
	} :: TEffectiveStats)
end

return StatCalculator
