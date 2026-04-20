--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ZoneConfig = require(ReplicatedStorage.Contexts.Quest.Config.ZoneConfig)

--[=[
	@interface TExpeditionViewModel
	View model for expedition status display.
	@within ExpeditionViewModel
	.StatusLabel string -- Human-readable status text (e.g. "Victory!", "In Combat")
	.StatusColor Color3 -- Color corresponding to the current status
	.ZoneName string -- Display name of the zone
	.PartySize number -- Number of adventurers in the party
	.GoldEarned number -- Gold received from the expedition
	.LootItems { TExpeditionLootItem } -- Itemized loot rows
	.DeadAdventurers { string } -- Adventurer IDs lost to permadeath
	.SurvivingParty { string } -- Adventurer IDs that returned
	.CanFlee boolean -- Whether the player can flee the expedition
	.IsActive boolean -- Whether the expedition is currently active
]=]
export type TExpeditionLootItem = {
	ItemId: string,
	Quantity: number,
}

export type TExpeditionViewModel = {
	StatusLabel: string,
	StatusColor: Color3,
	ZoneName: string,
	PartySize: number,
	GoldEarned: number,
	LootItems: { TExpeditionLootItem },
	DeadAdventurers: { string },
	SurvivingParty: { string },
	CanFlee: boolean,
	IsActive: boolean,
}

--[=[
	@class ExpeditionViewModel
	Transforms expedition state into a view model for display in the expedition result screen.
	@client
]=]
local ExpeditionViewModel = {}

local _CloneLootItems
local _CloneStringList
local _BuildSurvivingParty

--[=[
	Transform an expedition state into a view model for UI display.
	If expedition is nil, returns a default "no active expedition" state.
	@within ExpeditionViewModel
	@param expedition any? -- The expedition state object or nil
	@return TExpeditionViewModel -- Frozen view model with all display properties
]=]
function ExpeditionViewModel.fromExpeditionState(expedition: any?): TExpeditionViewModel
	if not expedition then
		return table.freeze({
			StatusLabel = "No Active Expedition",
			StatusColor = Color3.fromRGB(150, 150, 150),
			ZoneName = "",
			PartySize = 0,
			GoldEarned = 0,
			LootItems = {},
			DeadAdventurers = {},
			SurvivingParty = {},
			CanFlee = false,
			IsActive = false,
		} :: TExpeditionViewModel)
	end

	local statusLabels = {
		Preparing = "Preparing...",
		InCombat = "In Combat",
		Victory = "Victory",
		Defeat = "Defeated",
		Fled = "Fled",
	}

	local statusColors = {
		Victory = Color3.fromRGB(80, 200, 120),
		Defeat = Color3.fromRGB(200, 80, 80),
		Fled = Color3.fromRGB(200, 160, 60),
		InCombat = Color3.fromRGB(60, 160, 220),
		Preparing = Color3.fromRGB(60, 160, 220),
	}

	local zone = ZoneConfig[expedition.ZoneId]
	local zoneName = zone and zone.DisplayName or expedition.ZoneId

	local deadAdventurers = _CloneStringList(expedition.DeadAdventurerIds)
	local survivingParty = _BuildSurvivingParty(expedition.Party, deadAdventurers)

	return table.freeze({
		StatusLabel = statusLabels[expedition.Status] or expedition.Status,
		StatusColor = statusColors[expedition.Status] or Color3.fromRGB(150, 150, 150),
		ZoneName = zoneName,
		PartySize = #expedition.Party,
		GoldEarned = expedition.GoldEarned or 0,
		LootItems = _CloneLootItems(expedition.Loot),
		DeadAdventurers = deadAdventurers,
		SurvivingParty = survivingParty,
		CanFlee = expedition.Status == "InCombat",
		IsActive = expedition.Status == "InCombat" or expedition.Status == "Preparing",
	} :: TExpeditionViewModel)
end

function _CloneLootItems(loot: { TExpeditionLootItem }?): { TExpeditionLootItem }
	local items: { TExpeditionLootItem } = {}
	if not loot then
		return items
	end

	for _, item in ipairs(loot) do
		table.insert(items, {
			ItemId = item.ItemId,
			Quantity = item.Quantity,
		})
	end
	return items
end

function _CloneStringList(values: { string }?): { string }
	local cloned = {}
	if not values then
		return cloned
	end

	for _, value in ipairs(values) do
		table.insert(cloned, value)
	end
	return cloned
end

function _BuildSurvivingParty(party: { any }, deadAdventurerIds: { string }): { string }
	local survivingParty = {}
	for _, member in ipairs(party) do
		if not table.find(deadAdventurerIds, member.AdventurerId) then
			table.insert(survivingParty, member.AdventurerId)
		end
	end
	return survivingParty
end

return ExpeditionViewModel
