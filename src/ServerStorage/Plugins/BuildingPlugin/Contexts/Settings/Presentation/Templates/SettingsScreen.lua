--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useSettingsState = require(script.Parent.Parent.Parent.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Application.Hooks.useSettingsActions)
local SettingsViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.SettingsViewModel)
local FolderPresetsPanel = require(script.Parent.Parent.Organisms.FolderPresetsPanel)

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
		FolderPresets = React.createElement(FolderPresetsPanel, {
			OnPresetTextChanged = settingsActions.SetPresetText,
			OnSavePresets = settingsActions.SavePresets,
			PresetText = viewModel.PresetText,
			PreviewText = viewModel.PreviewText,
		}),
	})
end

return SettingsScreen
