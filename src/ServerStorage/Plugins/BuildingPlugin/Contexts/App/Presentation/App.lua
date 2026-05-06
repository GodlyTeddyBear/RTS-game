--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useAppState = require(script.Parent.Parent.Application.Hooks.useAppState)
local useAppActions = require(script.Parent.Parent.Application.Hooks.useAppActions)
local StatusBar = require(script.Parent.Atoms.StatusBar)
local BuildingPresentation = require(script.Parent.Parent.Parent.Building.Presentation)
local AssetsPresentation = require(script.Parent.Parent.Parent.Assets.Presentation)
local SettingsPresentation = require(script.Parent.Parent.Parent.Settings.Presentation)

local function App()
	local theme = StudioComponents.useTheme()
	local appState = useAppState()
	local appActions = useAppActions()

	return React.createElement("Frame", {
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		Size = UDim2.fromScale(1, 1),
	}, {
		Tabs = React.createElement(StudioComponents.TabContainer, {
			OnTabSelected = appActions.SetSelectedTab,
			SelectedTab = appState.SelectedTab,
			Size = UDim2.new(1, 0, 1, -28),
		}, {
			Building = {
				LayoutOrder = 1,
				Content = React.createElement(BuildingPresentation.Screen),
			},
			Settings = {
				LayoutOrder = 2,
				Content = React.createElement(SettingsPresentation.Screen),
			},
			Assets = {
				LayoutOrder = 3,
				Content = React.createElement(AssetsPresentation.Screen),
			},
		}),
		StatusBar = React.createElement(StatusBar, {
			Message = appState.Status.Message,
			Tone = appState.Status.Tone,
		}),
	})
end

return App
