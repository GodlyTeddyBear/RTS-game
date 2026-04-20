--!strict

--[=[
	@interface TPartyMemberViewModel
	View model for a single party member row in the party selection UI.
	@within PartySelectionViewModel
	.AdventurerId string -- Unique identifier for the adventurer
	.AdventurerType string -- Type or class of the adventurer
	.Name string -- Display name of the adventurer
	.AtkLabel string -- Formatted ATK stat label (e.g. "ATK 10")
	.DefLabel string -- Formatted DEF stat label (e.g. "DEF 5")
	.IsSelectable boolean -- Whether the adventurer can be selected (not on expedition)
	.IsOnExpedition boolean -- Whether the adventurer is currently on an expedition
]=]
export type TPartyMemberViewModel = {
	AdventurerId: string,
	AdventurerType: string,
	Name: string,
	AtkLabel: string,
	DefLabel: string,
	IsSelectable: boolean,
	IsOnExpedition: boolean,
}

--[=[
	@class PartySelectionViewModel
	Transforms adventurer roster data into UI view models for party selection screens.
	@client
]=]
local PartySelectionViewModel = {}

--[=[
	Transform the adventurer roster into view models for the party selection UI.
	Sorts available adventurers first, then by type.
	@within PartySelectionViewModel
	@param adventurers { [string]: any } -- All adventurers from guild state (keyed by ID)
	@return { TPartyMemberViewModel } -- Sorted array of party member view models
]=]
function PartySelectionViewModel.fromRoster(adventurers: { [string]: any }): { TPartyMemberViewModel }
	local vms = {}
	for adventurerId, adventurer in pairs(adventurers) do
		local isOnExpedition = adventurer.IsOnExpedition == true
		table.insert(vms, table.freeze({
			AdventurerId = adventurerId,
			AdventurerType = adventurer.Type,
			Name = adventurer.Name or adventurer.Type,
			AtkLabel = "ATK " .. tostring(adventurer.Atk or 0),
			DefLabel = "DEF " .. tostring(adventurer.Def or 0),
			IsSelectable = not isOnExpedition,
			IsOnExpedition = isOnExpedition,
		} :: TPartyMemberViewModel))
	end
	-- Sort: available first, then by type alphabetically
	table.sort(vms, function(a, b)
		if a.IsSelectable ~= b.IsSelectable then
			return a.IsSelectable
		end
		return a.AdventurerType < b.AdventurerType
	end)
	return vms
end

return PartySelectionViewModel
