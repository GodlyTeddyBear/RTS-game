--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useNavigation = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigation)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useGuildState = require(script.Parent.Parent.Parent.Parent.Guild.Application.Hooks.useGuildState)
local useQuestActions = require(script.Parent.useQuestActions)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local ZoneViewModel = require(script.Parent.Parent.ViewModels.ZoneViewModel)
local PartySelectionViewModel = require(script.Parent.Parent.ViewModels.PartySelectionViewModel)

--[=[
	@interface TQuestPartySelectionController
	Controller state for the party selection screen.
	@within useQuestPartySelectionController
	.zoneVM ZoneViewModel.TZoneViewModel? -- The selected zone details
	.partyVMs { PartySelectionViewModel.TPartyMemberViewModel } -- Available adventurers as view models
	.selectedIds { string } -- IDs of currently selected adventurers
	.screenTitle string -- Screen title showing the zone name
	.partySizeLabel string -- Formatted party size requirement (e.g. "1-3 Adventurers")
	.canDepart boolean -- Whether the current selection meets zone requirements
	.isSelected (adventurerId: string) -> boolean -- Check if an adventurer is selected
	.onToggleAdventurer (adventurerId: string) -> () -- Toggle selection of an adventurer
	.onConfirm () -> () -- Depart with the selected party
	.onBack () -> () -- Return to quest board
]=]
export type TQuestPartySelectionController = {
	zoneVM: ZoneViewModel.TZoneViewModel?,
	partyVMs: { PartySelectionViewModel.TPartyMemberViewModel },
	selectedIds: { string },
	screenTitle: string,
	partySizeLabel: string,
	canDepart: boolean,
	isSelected: (adventurerId: string) -> boolean,
	onToggleAdventurer: (adventurerId: string) -> (),
	onConfirm: () -> (),
	onBack: () -> (),
}

--[=[
	@function useQuestPartySelectionController
	@within useQuestPartySelectionController
	Compose state and actions for party selection UI.
	Manages adventurer selection, party size validation, and departure logic.
	@return TQuestPartySelectionController
]=]
local function useQuestPartySelectionController(): TQuestPartySelectionController
	local navState = useNavigation()
	local navActions = useNavigationActions()
	local adventurers = useGuildState()
	local questActions = useQuestActions()
	local soundActions = useSoundActions()

	local params = navState and navState.Params or {}
	local zoneId = params and params.zoneId or ""

	local zoneVM = ZoneViewModel.fromZoneConfig(zoneId)
	local partyVMs = PartySelectionViewModel.fromRoster(adventurers)

	local selectedIds, setSelectedIds = React.useState({} :: { string })

	local minParty = zoneVM and zoneVM.MinPartySize or 1
	local maxParty = zoneVM and zoneVM.MaxPartySize or 5
	local canDepart = #selectedIds >= minParty and #selectedIds <= maxParty

	-- Check if an adventurer is in the selected list.
	local function isSelected(adventurerId: string): boolean
		for _, id in ipairs(selectedIds) do
			if id == adventurerId then
				return true
			end
		end
		return false
	end

	-- Add or remove an adventurer from the selection.
	local function onToggleAdventurer(adventurerId: string)
		soundActions.playButtonClick()
		local newSelected = table.clone(selectedIds)
		local found = false
		for i, id in ipairs(newSelected) do
			if id == adventurerId then
				table.remove(newSelected, i)
				found = true
				break
			end
		end
		if not found then
			table.insert(newSelected, adventurerId)
		end
		setSelectedIds(newSelected)
	end

	-- Depart with selected party if selection is valid.
	local function onConfirm()
		if not canDepart then
			soundActions.playError()
			return
		end
		if zoneId ~= "" then
			soundActions.playButtonClick("confirm")
			local result = questActions.departOnQuest(zoneId, selectedIds)
			if result then
				result:catch(function()
					soundActions.playError()
				end)
			end
			navActions.navigate("Game")
		end
	end

	return {
		zoneVM = zoneVM,
		partyVMs = partyVMs,
		selectedIds = selectedIds,
		screenTitle = if zoneVM then "Send to " .. zoneVM.DisplayName else "Send to",
		partySizeLabel = tostring(minParty) .. "-" .. tostring(maxParty) .. " Adventurers",
		canDepart = canDepart,
		isSelected = isSelected,
		onToggleAdventurer = onToggleAdventurer,
		onConfirm = onConfirm,
		onBack = function()
			soundActions.playMenuClose("QuestParty")
			navActions.goBack()
		end,
	}
end

return useQuestPartySelectionController
