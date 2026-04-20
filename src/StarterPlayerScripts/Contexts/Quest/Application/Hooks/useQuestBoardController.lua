--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useQuestState = require(script.Parent.useQuestState)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)
local useUnlockState = require(script.Parent.Parent.Parent.Parent.Unlock.Application.Hooks.useUnlockState)

local ZoneViewModel = require(script.Parent.Parent.ViewModels.ZoneViewModel)
local ExpeditionViewModel = require(script.Parent.Parent.ViewModels.ExpeditionViewModel)

--[=[
	@interface TQuestBoardController
	Controller state for the quest board screen.
	@within useQuestBoardController
	.anim any -- Animation controller from useScreenTransition
	.activeTier string -- Currently selected difficulty tier filter
	.filteredZoneVMs { ZoneViewModel.TZoneViewModel } -- Zones matching active tier
	.expeditionVM ExpeditionViewModel.TExpeditionViewModel -- Current expedition status
	.isExpeditionActive boolean -- Whether an expedition is currently in progress
	.onTierSelect (tier: string) -> () -- Called when user selects a tier tab
	.onBack () -> () -- Called when user presses back
	.onAcceptZone (zoneId: string) -> () -- Called when user selects a zone to quest
	.onViewExpedition () -> () -- Called when user clicks to view active expedition
]=]
export type TQuestBoardController = {
	anim: any,
	activeTier: string,
	filteredZoneVMs: { ZoneViewModel.TZoneViewModel },
	expeditionVM: ExpeditionViewModel.TExpeditionViewModel,
	isExpeditionActive: boolean,
	onTierSelect: (tier: string) -> (),
	onBack: () -> (),
	onAcceptZone: (zoneId: string) -> (),
	onViewExpedition: () -> (),
}

-- Filter zones by difficulty tier; "all" returns all zones.
local function filterByTier(vms: { ZoneViewModel.TZoneViewModel }, tier: string): { ZoneViewModel.TZoneViewModel }
	if tier == "all" then
		return vms
	end
	local filtered = {}
	for _, vm in ipairs(vms) do
		if string.lower(vm.TierLabel) == tier then
			table.insert(filtered, vm)
		end
	end
	return filtered
end

local function findZoneById(vms: { ZoneViewModel.TZoneViewModel }, zoneId: string): ZoneViewModel.TZoneViewModel?
	for _, vm in ipairs(vms) do
		if vm.ZoneId == zoneId then
			return vm
		end
	end
	return nil
end

--[=[
	@function useQuestBoardController
	@within useQuestBoardController
	Compose state and actions for the quest board UI.
	Subscribes to quest state and provides tier filtering, zone display, and expedition status.
	@return TQuestBoardController
]=]
local function useQuestBoardController(): TQuestBoardController
	local questState = useQuestState()
	local navActions = useNavigationActions()
	local soundActions = useSoundActions()
	local unlockState = useUnlockState()
	local activeTier, setActiveTier = React.useState("all" :: string)

	local activeExpedition = questState and questState.ActiveExpedition or nil
	local isExpeditionActive = activeExpedition ~= nil

	local expeditionVM = ExpeditionViewModel.fromExpeditionState(activeExpedition)
	local allZoneVMs = ZoneViewModel.buildAll(unlockState)
	local filteredZoneVMs = filterByTier(allZoneVMs, activeTier)

	return {
		activeTier = activeTier,
		filteredZoneVMs = filteredZoneVMs,
		expeditionVM = expeditionVM,
		isExpeditionActive = isExpeditionActive,
		onTierSelect = function(tier: string)
			soundActions.playTabSwitch(tier)
			setActiveTier(tier)
		end,
		onBack = function()
			soundActions.playMenuClose("QuestBoard")
			navActions.goBack()
		end,
		onAcceptZone = function(zoneId: string)
			local zoneVM = findZoneById(allZoneVMs, zoneId)
			if not zoneVM or not zoneVM.IsUnlocked then
				soundActions.playError()
				return
			end
			soundActions.playButtonClick()
			navActions.navigate("QuestPartySelection", { zoneId = zoneId })
		end,
		onViewExpedition = function()
			soundActions.playButtonClick()
			navActions.navigate("QuestExpeditionResult")
		end,
	}
end

return useQuestBoardController
