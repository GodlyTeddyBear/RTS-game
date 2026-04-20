--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Contexts = script.Parent.Parent.Parent.Parent
local ScreenHeader = require(Contexts.App.Presentation.Organisms.ScreenHeader)
local useNavigationActions = require(Contexts.App.Application.Hooks.useNavigationActions)
local useScreenTransition = require(Contexts.App.Application.Hooks.useScreenTransition)

local useSettingsState = require(script.Parent.Parent.Parent.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Application.Hooks.useSettingsActions)
local SettingsViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.SettingsViewModel)
local SoundSettingsPanel = require(script.Parent.Parent.Organisms.SoundSettingsPanel)

local function SettingsScreen()
	local settings = useSettingsState()
	local actions = useSettingsActions()
	local navigationActions = useNavigationActions()
	local anim = useScreenTransition("Simple")

	local viewModel = React.useMemo(function()
		return SettingsViewModel.fromSettings(settings)
	end, { settings })

	return e("Frame", {
		ref = anim.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 18, 18),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 0,
	}, {
		Header = e(ScreenHeader, {
			Title = "Settings",
			OnBack = navigationActions.goBack,
			Position = UDim2.fromScale(0.5, 0.049),
			AnchorPoint = Vector2.new(0.5, 0.5),
		}),
		Sound = e(SoundSettingsPanel, {
			ViewModel = viewModel,
			OnSetVolume = actions.setSoundVolume,
			OnSetEnabled = actions.setSoundEnabled,
		}),
	})
end

return SettingsScreen
