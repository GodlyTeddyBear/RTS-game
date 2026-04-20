--!strict

--[=[
	@class DamageCalculator
	Pure domain service for damage calculation.

	Formula: `damage = max(1, ATK - DEF)`. Simple subtraction with a minimum
	of 1 damage to prevent defend-stacking from reducing damage to 0.
	@server
]=]

local DamageCalculator = {}
DamageCalculator.__index = DamageCalculator

export type TDamageCalculator = typeof(setmetatable({}, DamageCalculator))

function DamageCalculator.new(): TDamageCalculator
	local self = setmetatable({}, DamageCalculator)
	return self
end

--[=[
	Calculate damage dealt by an attacker to a defender.
	@within DamageCalculator
	@param attackerATK number -- Attacker's ATK stat
	@param defenderDEF number -- Defender's DEF stat
	@return number -- Damage amount (minimum 1)
]=]
function DamageCalculator:Calculate(attackerATK: number, defenderDEF: number): number
	return math.max(1, attackerATK - defenderDEF)
end

return DamageCalculator
