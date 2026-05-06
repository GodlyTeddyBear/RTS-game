--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useBuildingState = require(script.Parent.Parent.Parent.Application.Hooks.useBuildingState)
local useBuildingActions = require(script.Parent.Parent.Parent.Application.Hooks.useBuildingActions)
local BuildingViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.BuildingViewModel)
local useSettingsState = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsState)
local SelectionSummaryPanel = require(script.Parent.Parent.Organisms.SelectionSummaryPanel)
local FolderToolsPanel = require(script.Parent.Parent.Organisms.FolderToolsPanel)
local SelectionActionsPanel = require(script.Parent.Parent.Organisms.SelectionActionsPanel)
local PropertyShortcutsPanel = require(script.Parent.Parent.Organisms.PropertyShortcutsPanel)

local function BuildingScreen()
	local buildingState = useBuildingState()
	local buildingActions = useBuildingActions()
	local settingsState = useSettingsState()

	React.useEffect(function()
		buildingActions.RefreshSelectionSummary()
	end, {})

	local viewModel = React.useMemo(function()
		return BuildingViewModel.FromState(buildingState)
	end, { buildingState })

	return React.createElement(StudioComponents.ScrollFrame, {
		Layout = {
			ClassName = "UIListLayout",
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 10),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}, {
		SelectionSummary = React.createElement(SelectionSummaryPanel, {
			SelectionText = viewModel.SelectionText,
		}),
		FolderTools = React.createElement(FolderToolsPanel, {
			FolderName = viewModel.FolderName,
			FolderPresets = settingsState.FolderPresets,
			OnFolderNameChanged = buildingActions.SetFolderName,
			OnUseFolderPreset = buildingActions.UseFolderPreset,
			OnWrapSelection = buildingActions.WrapSelection,
		}),
		SelectionActions = React.createElement(SelectionActionsPanel, {
			OnDuplicateSelection = buildingActions.DuplicateSelection,
		}),
		PropertyShortcuts = React.createElement(PropertyShortcutsPanel, {
			OnPropertyAction = buildingActions.RunPropertyAction,
		}),
	})
end

return BuildingScreen
