--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdventurerConfig = require(ReplicatedStorage.Contexts.Guild.Config.AdventurerConfig)
local GuildConfig = require(ReplicatedStorage.Contexts.Guild.Config.GuildConfig)

export type THireOptionViewModel = {
	Type: string,
	DisplayName: string,
	Description: string,
	HPLabel: string,
	ATKLabel: string,
	DEFLabel: string,
	StatsLabel: string,
	CostLabel: string,
	CostDisplay: string,
	HireCost: number,
	CanAfford: boolean,
	RosterFull: boolean,
}

local HireRosterViewModel = {}

--- Builds the full catalog of hire options
function HireRosterViewModel.buildCatalog(currentGold: number, currentRosterSize: number): { THireOptionViewModel }
	local catalog = {}

	-- Check if roster is at capacity
	local rosterFull = currentRosterSize >= GuildConfig.MAX_ROSTER_SIZE

	-- Build a ViewModel for each adventurer type with affordability/capacity flags
	for _, config in pairs(AdventurerConfig) do
		table.insert(catalog, table.freeze({
			Type = config.Type,
			DisplayName = config.DisplayName,
			Description = config.Description,
			HPLabel = "HP: " .. tostring(config.BaseHP),
			ATKLabel = "ATK: " .. tostring(config.BaseATK),
			DEFLabel = "DEF: " .. tostring(config.BaseDEF),
			StatsLabel = "DEF:" .. tostring(config.BaseDEF) .. " HP:" .. tostring(config.BaseHP) .. " ATK:" .. tostring(config.BaseATK),
			CostLabel = tostring(config.HireCost) .. " Gold",
			CostDisplay = "$" .. tostring(config.HireCost),
			HireCost = config.HireCost,
			CanAfford = currentGold >= config.HireCost,
			RosterFull = rosterFull,
		} :: THireOptionViewModel))
	end

	-- Sort by hire cost ascending to guide player progression
	table.sort(catalog, function(a, b)
		return a.HireCost < b.HireCost
	end)

	return catalog
end

return HireRosterViewModel
