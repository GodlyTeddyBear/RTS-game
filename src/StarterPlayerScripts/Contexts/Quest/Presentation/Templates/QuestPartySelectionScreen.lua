--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)

local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local PartySelectionStatusBar = require(script.Parent.Parent.Organisms.PartySelectionStatusBar)
local AdventurerSelectRow = require(script.Parent.Parent.Organisms.AdventurerSelectRow)
local QuestPartySelectionScreenView = require(script.Parent.QuestPartySelectionScreenView)

local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useStaggeredMount = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useStaggeredMount)

local useQuestPartySelectionController = require(script.Parent.Parent.Parent.Application.Hooks.useQuestPartySelectionController)
local PartySelectionViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.PartySelectionViewModel)

-- Wrapper that only renders after a staggered delay for list entry animations.
type TStaggeredRowProps = {
	vm: PartySelectionViewModel.TPartyMemberViewModel,
	IsSelected: boolean,
	OnToggle: (id: string) -> (),
	LayoutOrder: number,
	Index: number,
}

local function StaggeredAdventurerRow(props: TStaggeredRowProps)
	local isVisible = useStaggeredMount(props.Index, AnimationTokens.Stagger.List)
	if not isVisible then
		return nil
	end
	return e(AdventurerSelectRow, {
		vm = props.vm,
		IsSelected = props.IsSelected,
		OnToggle = props.OnToggle,
		LayoutOrder = props.LayoutOrder,
	})
end

--[=[
	@class QuestPartySelectionScreen
	Screen for selecting which adventurers to send on a quest.
	Validates selection against zone party size limits and allows confirmation.
	@client
]=]
local function QuestPartySelectionScreen()
	local anim = useScreenTransition("Standard")
	local ctrl = useQuestPartySelectionController()

	-- Build adventurer rows
	local adventurerRows: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
			PaddingTop = UDim.new(0.015, 0),
			PaddingBottom = UDim.new(0.015, 0),
		}),
	}

	for i, vm in ipairs(ctrl.partyVMs) do
		adventurerRows["Adv_" .. vm.AdventurerId] = e(StaggeredAdventurerRow, {
			vm = vm,
			IsSelected = ctrl.isSelected(vm.AdventurerId),
			OnToggle = ctrl.onToggleAdventurer,
			LayoutOrder = i,
			Index = i,
		})
	end

	return e(QuestPartySelectionScreenView, {
		containerRef = anim.containerRef,
		screenTitle = ctrl.screenTitle,
		onBack = ctrl.onBack,
		selectedCount = #ctrl.selectedIds,
		partySizeLabel = ctrl.partySizeLabel,
		onConfirm = ctrl.onConfirm,
		confirmEnabled = ctrl.canDepart,
		adventurerRows = adventurerRows,
	})
end

return QuestPartySelectionScreen
