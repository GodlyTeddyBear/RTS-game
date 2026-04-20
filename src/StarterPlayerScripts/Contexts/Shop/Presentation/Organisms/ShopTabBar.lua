--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local TabButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Molecules.TabButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

--[=[
	@interface TShopTabBarProps
	Props for the Shop tab bar.
	.GoldDisplay string -- Pre-formatted animated gold display string
	.ActiveTab "buy" | "sell" -- Currently active tab
	.OnTabSelect (tab: "buy" | "sell") -> () -- Tab selection callback
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
]=]
export type TShopTabBarProps = {
	GoldDisplay: string,
	ActiveTab: "buy" | "sell",
	OnTabSelect: (tab: "buy" | "sell") -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

-- Tab button styling configuration: gradients, strokes, and labels for each tab type.
local TAB_CONFIG = {
	buy = {
		activeGradient = GradientTokens.GREEN_BUTTON_GRADIENT,
		activeStroke = GradientTokens.GREEN_BUTTON_STROKE,
		labelStrokeColor = GradientTokens.BUY_TAB_LABEL_STROKE_COLOR,
		label = "Buy",
	},
	sell = {
		activeGradient = GradientTokens.ASSIGN_BUTTON_GRADIENT,
		activeStroke = GradientTokens.ASSIGN_BUTTON_STROKE,
		labelStrokeColor = GradientTokens.SELL_TAB_LABEL_STROKE_COLOR,
		label = "Sell",
	},
}

-- Render order for tab buttons.
local TAB_ORDER: { "buy" | "sell" } = { "buy", "sell" }

-- Stable per-tab OnSelect callbacks keyed by tab id. Built once at module level since
-- they only capture the tab key, not any per-render state.
local function _makeTabCallbacks(onTabSelect: (tab: "buy" | "sell") -> ()): { ["buy"]: () -> (), ["sell"]: () -> () }
	return {
		buy = function() onTabSelect("buy") end,
		sell = function() onTabSelect("sell") end,
	}
end

--[=[
	@class ShopTabBar
	Tab bar for switching between buy and sell modes, with an animated gold counter display.
	@client
]=]

--[=[
	Render the Shop tab bar with buy/sell tabs and animated gold display.
	@within ShopTabBar
	@param props TShopTabBarProps
	@return React.ReactElement -- Tab bar component
]=]
local function ShopTabBar(props: TShopTabBarProps)
	local tabCallbacks = React.useMemo(function()
		return _makeTabCallbacks(props.OnTabSelect)
	end, { props.OnTabSelect } :: { any })

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

	for i, tabKey in ipairs(TAB_ORDER) do
		local config = TAB_CONFIG[tabKey]
		tabChildren["Tab_" .. tabKey] = e(TabButton, {
			Label = config.label,
			IsActive = tabKey == props.ActiveTab,
			LayoutOrder = i,
			Width = UDim2.fromScale(0.12551, 0.90909),
			ActiveGradient = config.activeGradient,
			ActiveDecoreStroke = config.activeStroke,
			ActiveLabelStrokeColor = config.labelStrokeColor,
			GradientRotation = -141,
			FontFamily = "rbxasset://fonts/families/GothamSSm.json",
			OnSelect = tabCallbacks[tabKey],
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
				FontFace = TypographyTokens.FontFace.Bold,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.02431, 0.4918),
				Size = UDim2.fromScale(0.09236, 0.4918),
			}),

			GoldAmount = e("TextLabel", {
				Text = props.GoldDisplay,
				FontFace = TypographyTokens.FontFace.Body,
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0.12847, 0.4918),
				Size = UDim2.fromScale(0.09931, 0.4918),
			}),

			Container = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.61528, 0.4918),
				Size = UDim2.fromScale(0.68056, 0.72131),
			}, tabChildren),
		},
	})
end

return ShopTabBar
