--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local TabButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Molecules.TabButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local useCountUp = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useCountUp)

-- Color config per tab
local TAB_CONFIG = {
	roster = {
		label = "Roster",
		activeGradient = GradientTokens.ASSIGN_BUTTON_GRADIENT,
		activeStroke = GradientTokens.ASSIGN_BUTTON_STROKE,
		labelStrokeColor = Color3.fromRGB(200, 24, 28),
	},
	commission = {
		label = "Commission",
		activeGradient = GradientTokens.OPTIONS_BUTTON_GRADIENT,
		activeStroke = GradientTokens.OPTIONS_BUTTON_STROKE,
		labelStrokeColor = Color3.fromRGB(120, 16, 134),
	},
	hire = {
		label = "Hire",
		activeGradient = GradientTokens.GREEN_BUTTON_GRADIENT,
		activeStroke = GradientTokens.GREEN_BUTTON_STROKE,
		labelStrokeColor = Color3.fromRGB(12, 44, 20),
	},
	adventure = {
		label = "Adventure",
		activeGradient = GradientTokens.TAB_ACTIVE_GRADIENT,
		activeStroke = GradientTokens.TAB_ACTIVE_STROKE,
		labelStrokeColor = Color3.fromRGB(36, 29, 0),
	},
}

local TAB_ORDER = { "roster", "commission", "hire", "adventure" }

export type TGuildTabBarProps = {
	Gold: number,
	RosterCount: number,
	MaxRoster: number,
	ActiveTab: string,
	OnTabSelect: (tab: string) -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

local function GuildTabBar(props: TGuildTabBarProps)
	local goldDisplay = useCountUp(props.Gold, { Duration = 0.3, Suffix = " Gold" })

	local tabChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.015, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
	}

	-- Render tab buttons in defined order
	for i, tabKey in ipairs(TAB_ORDER) do
		local config = TAB_CONFIG[tabKey]
		tabChildren["Tab_" .. tabKey] = e(TabButton, {
			Label = config.label,
			IsActive = tabKey == props.ActiveTab,
			LayoutOrder = i,
			Width = UDim2.fromScale(0.22, 0.90909),
			ActiveGradient = config.activeGradient,
			ActiveDecoreStroke = config.activeStroke,
			ActiveLabelStrokeColor = config.labelStrokeColor,
			OnSelect = function()
				props.OnTabSelect(tabKey)
			end,
		})
	end

	return e(Frame, {
		Size = UDim2.fromScale(1, 0.05957),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		LayoutOrder = 2,
		ClipsDescendants = true,
		children = {
			GoldLabel = e("TextLabel", {
				Text = "Gold:",
				FontFace = Font.new(
					"rbxasset://fonts/families/GothicA1.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.05347, 0.4918),
				Size = UDim2.fromScale(0.06319, 0.4918),
			}),

			GoldAmount = e("TextLabel", {
				Text = goldDisplay,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.12847, 0.4918),
				Size = UDim2.fromScale(0.09931, 0.4918),
			}),

			RosterLabel = e("TextLabel", {
				Text = "Roster:",
				FontFace = Font.new(
					"rbxasset://fonts/families/GothicA1.json",
					Enum.FontWeight.Bold,
					Enum.FontStyle.Normal
				),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.27, 0.4918),
				Size = UDim2.fromScale(0.085, 0.64),
			}),

			RosterAmount = e("TextLabel", {
				Text = tostring(props.RosterCount) .. "/" .. tostring(props.MaxRoster),
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.358, 0.4918),
				Size = UDim2.fromScale(0.12, 0.64),
			}),

			Container = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.72, 0.4918),
				Size = UDim2.fromScale(0.44, 0.72131),
			}, tabChildren),
		},
	})
end

return GuildTabBar
