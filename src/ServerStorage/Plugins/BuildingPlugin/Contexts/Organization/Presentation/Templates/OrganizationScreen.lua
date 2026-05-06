--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useOrganizationState = require(script.Parent.Parent.Parent.Application.Hooks.useOrganizationState)
local useOrganizationActions = require(script.Parent.Parent.Parent.Application.Hooks.useOrganizationActions)
local OrganizationViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.OrganizationViewModel)
local useSettingsState = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsActions)
local GroupByNamePanel = require(script.Parent.Parent.Organisms.GroupByNamePanel)
local PresetFoldersPanel = require(script.Parent.Parent.Organisms.PresetFoldersPanel)

local SECTION_IDS = {
	GroupByName = "organization_group_by_name",
	CreatePresetFolders = "organization_create_preset_folders",
}

local ORGANIZATION_SECTION_IDS = {
	SECTION_IDS.GroupByName,
	SECTION_IDS.CreatePresetFolders,
}

local function isSectionExpanded(sectionExpansionById: { [string]: boolean }, sectionId: string): boolean
	local value = sectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

local function OrganizationScreen()
	local organizationState = useOrganizationState()
	local organizationActions = useOrganizationActions()
	local settingsState = useSettingsState()
	local settingsActions = useSettingsActions()

	local viewModel = React.useMemo(function()
		return OrganizationViewModel.FromState(organizationState, settingsState)
	end, { organizationState, settingsState })

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
					settingsActions.SetSectionsExpanded(ORGANIZATION_SECTION_IDS, true)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Expand All",
			}),
			CollapseAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 2,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(ORGANIZATION_SECTION_IDS, false)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Collapse All",
			}),
		}),
		GroupByName = React.createElement(GroupByNamePanel, {
			SectionId = SECTION_IDS.GroupByName,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.GroupByName),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			MatchObjectName = viewModel.MatchObjectName,
			DestinationFolderName = viewModel.DestinationFolderName,
			SelectedChildName = viewModel.SelectedChildName,
			AvailableChildNames = viewModel.AvailableChildNames,
			InstructionText = viewModel.InstructionText,
			NameSelectorHelpText = viewModel.NameSelectorHelpText,
			MatchNameHelpText = viewModel.MatchNameHelpText,
			DestinationNameHelpText = viewModel.DestinationNameHelpText,
			OnMatchObjectNameChanged = organizationActions.SetMatchObjectName,
			OnDestinationFolderNameChanged = organizationActions.SetDestinationFolderName,
			OnSelectedChildNameChanged = organizationActions.SetSelectedChildName,
			OnGroupByName = organizationActions.GroupChildrenByName,
		}),
		PresetFolders = React.createElement(PresetFoldersPanel, {
			SectionId = SECTION_IDS.CreatePresetFolders,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.CreatePresetFolders),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			PresetLabels = viewModel.PresetLabels,
			SelectedPresetLabel = viewModel.SelectedPresetLabel,
			OnSelectedPresetLabelChanged = organizationActions.SetSelectedPresetLabel,
			OnCreatePresetFolders = organizationActions.CreatePresetFolders,
		}),
	})
end

return OrganizationScreen
