--!strict
--[=[
	@class TopBar
	Top navigation bar molecule displaying player profile, settings, and menu toggle buttons with gradient styling.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Atoms.Frame)
local IconButton = require(script.Parent.Parent.Atoms.IconButton)
local PlayerProfile = require(script.Parent.PlayerProfile)
local GradientTokens = require(script.Parent.Parent.Parent.Config.GradientTokens)

export type TTopBarProps = {
	OnToggleMenu: () -> (),
	OnOpenSettings: () -> (),
	PlayerUsername: string,
	PlayerLevel: number,
}

local function TopBar(props: TTopBarProps)
	return e(Frame, {
		Size = UDim2.fromScale(1, 0.147),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), -- white base needed for UIGradient tinting
		BackgroundTransparency = 0,
		ClipsDescendants = true,
		Gradient = GradientTokens.BAR_GRADIENT,
		StrokeColor = GradientTokens.GOLD_STROKE,
		StrokeThickness = 3,
		StrokeMode = Enum.ApplyStrokeMode.Border,
		StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
		children = {
			-- Sidebar toggle button (left side)
			SidebarButton = e(IconButton, {
				Icon = "menu",
				ImageId = GradientTokens.ICON_SIDEBAR,
				ImageColor3 = Color3.new(1, 1, 1),
				ImageSize = UDim2.fromScale(0.75, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.216, 0.5),
				Size = UDim2.fromScale(0.069, 0.75),
				Variant = "ghost",
				ClipsDescendants = true,
				Gradient = GradientTokens.BUTTON_GRADIENT,
				GradientRotation = -141,
				StrokeColor = GradientTokens.GOLD_STROKE,
				StrokeThickness = 3,
				CornerRadius = UDim.new(0, 0),
				[React.Event.Activated] = props.OnToggleMenu,
			}),

			-- Profile container (right side - name + level)
			ProfileContainer = e(PlayerProfile, {
				Username = props.PlayerUsername,
				Level = props.PlayerLevel,
				Position = UDim2.fromScale(0.8, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromScale(0.167, 0.607),
			}),

			-- Settings button (far right)
			SettingsButton = e(IconButton, {
				Icon = "settings",
				ImageId = GradientTokens.ICON_SETTINGS,
				ImageColor3 = Color3.fromRGB(217, 217, 217),
				ImageSize = UDim2.fromScale(0.85, 0.85),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.937, 0.5),
				Size = UDim2.fromScale(0.078, 0.75),
				Variant = "ghost",
				ClipsDescendants = true,
				Gradient = GradientTokens.BUTTON_GRADIENT,
				GradientRotation = -225,
				StrokeColor = GradientTokens.GOLD_STROKE,
				StrokeThickness = 3,
				CornerRadius = UDim.new(0, 0),
				[React.Event.Activated] = props.OnOpenSettings,
			}),
		},
	})
end

return TopBar
