--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useBuildingState = require(script.Parent.Parent.Parent.Application.Hooks.useBuildingState)
local useBuildingActions = require(script.Parent.Parent.Parent.Application.Hooks.useBuildingActions)
local BuildingViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.BuildingViewModel)
local useSettingsState = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsActions)
local SelectionSummaryPanel = require(script.Parent.Parent.Organisms.SelectionSummaryPanel)
local FolderToolsPanel = require(script.Parent.Parent.Organisms.FolderToolsPanel)
local SelectionActionsPanel = require(script.Parent.Parent.Organisms.SelectionActionsPanel)
local PropertyShortcutsPanel = require(script.Parent.Parent.Organisms.PropertyShortcutsPanel)

local SECTION_IDS = {
	SelectionSummary = "selection_summary",
	FolderTools = "folder_tools",
	SelectionActions = "selection_actions",
	PropertyShortcuts = "property_shortcuts",
}

local BUILDING_SECTION_IDS = {
	SECTION_IDS.SelectionSummary,
	SECTION_IDS.FolderTools,
	SECTION_IDS.SelectionActions,
	SECTION_IDS.PropertyShortcuts,
}

local function isSectionExpanded(sectionExpansionById: { [string]: boolean }, sectionId: string): boolean
	local value = sectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

local function BuildingScreen()
	local buildingState = useBuildingState()
	local buildingActions = useBuildingActions()
	local settingsState = useSettingsState()
	local settingsActions = useSettingsActions()

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
		SectionControls = React.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 24),
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ExpandAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 1,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(BUILDING_SECTION_IDS, true)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Expand All",
			}),
			CollapseAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 2,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(BUILDING_SECTION_IDS, false)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Collapse All",
			}),
		}),
		SelectionSummary = React.createElement(SelectionSummaryPanel, {
			SectionId = SECTION_IDS.SelectionSummary,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.SelectionSummary),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			SelectionText = viewModel.SelectionText,
		}),
		FolderTools = React.createElement(FolderToolsPanel, {
			SectionId = SECTION_IDS.FolderTools,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.FolderTools),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			FolderName = viewModel.FolderName,
			FolderPresets = settingsState.FolderPresets,
			OnFolderNameChanged = buildingActions.SetFolderName,
			OnUseFolderPreset = buildingActions.UseFolderPreset,
			OnWrapSelection = buildingActions.WrapSelection,
		}),
		SelectionActions = React.createElement(SelectionActionsPanel, {
			SectionId = SECTION_IDS.SelectionActions,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.SelectionActions),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			OnDuplicateSelection = buildingActions.DuplicateSelection,
		}),
		PropertyShortcuts = React.createElement(PropertyShortcutsPanel, {
			SectionId = SECTION_IDS.PropertyShortcuts,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.PropertyShortcuts),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			OnPropertyAction = buildingActions.RunPropertyAction,
		}),
	})
end

return BuildingScreen
