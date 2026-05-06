--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useSettingsState = require(script.Parent.Parent.Parent.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Application.Hooks.useSettingsActions)
local SettingsViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.SettingsViewModel)
local PresetGroupsPanel = require(script.Parent.Parent.Organisms.PresetGroupsPanel)

local SECTION_ID = "folder_preset_groups"
local SETTINGS_SECTION_IDS = { SECTION_ID }

local function isSectionExpanded(sectionExpansionById: { [string]: boolean }, sectionId: string): boolean
	local value = sectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

local function SettingsScreen()
	local settingsState = useSettingsState()
	local settingsActions = useSettingsActions()

	React.useEffect(function()
		settingsActions.RefreshSettings()
	end, {})

	local viewModel = React.useMemo(function()
		return SettingsViewModel.FromState(settingsState)
	end, { settingsState })

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
					settingsActions.SetSectionsExpanded(SETTINGS_SECTION_IDS, true)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Expand All",
			}),
			CollapseAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 2,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(SETTINGS_SECTION_IDS, false)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Collapse All",
			}),
		}),
		PresetGroups = React.createElement(PresetGroupsPanel, {
			SectionId = SECTION_ID,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_ID),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			PresetGroupLabelInput = viewModel.PresetGroupLabelInput,
			PresetGroupFolderNamesInput = viewModel.PresetGroupFolderNamesInput,
			PresetGroupIncludesInput = viewModel.PresetGroupIncludesInput,
			GroupLabels = viewModel.GroupLabels,
			SelectedPresetGroupLabel = viewModel.SelectedPresetGroupLabel,
			PreviewText = viewModel.PreviewText,
			HelpText = viewModel.HelpText,
			ExampleText = viewModel.ExampleText,
			StructurePreviewText = viewModel.StructurePreviewText,
			OnPresetGroupLabelInputChanged = settingsActions.SetPresetGroupLabelInput,
			OnPresetGroupFolderNamesInputChanged = settingsActions.SetPresetGroupFolderNamesInput,
			OnPresetGroupIncludesInputChanged = settingsActions.SetPresetGroupIncludesInput,
			OnSelectedPresetGroupLabelChanged = settingsActions.SetSelectedPresetGroupLabel,
			OnSavePresetGroup = settingsActions.SavePresetGroup,
			OnLoadSelectedPresetGroup = settingsActions.LoadSelectedPresetGroup,
			OnDeleteSelectedPresetGroup = settingsActions.DeleteSelectedPresetGroup,
		}),
	})
end

return SettingsScreen
