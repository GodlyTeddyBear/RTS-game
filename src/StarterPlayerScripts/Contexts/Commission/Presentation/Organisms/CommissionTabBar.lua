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
	available = {
		label = "Available",
		activeGradient = GradientTokens.ASSIGN_BUTTON_GRADIENT,
		activeStroke = GradientTokens.ASSIGN_BUTTON_STROKE,
		labelStrokeColor = Color3.fromRGB(200, 24, 28),
	},
	active = {
		label = "Active",
		activeGradient = GradientTokens.GREEN_BUTTON_GRADIENT,
		activeStroke = GradientTokens.GREEN_BUTTON_STROKE,
		labelStrokeColor = Color3.fromRGB(12, 44, 20),
	},
	refresh = {
		label = "Refresh",
		activeGradient = GradientTokens.OPTIONS_BUTTON_GRADIENT,
		activeStroke = GradientTokens.OPTIONS_BUTTON_STROKE,
		labelStrokeColor = Color3.fromRGB(120, 16, 134),
	},
}

local TAB_ORDER = { "available", "active", "refresh" }

--[=[
	@interface TCommissionTabBarProps
	Props for CommissionTabBar.
	.TierLabel string -- Current tier display label
	.Tokens number -- Current token count
	.ActiveTab string -- Currently selected tab ("available" or "active")
	.OnTabSelect (tab: string) -> () -- Callback when tab button clicked
	.OnRefresh () -> () -- Callback when refresh button clicked
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
]=]

export type TCommissionTabBarProps = {
	TierLabel: string,
	Tokens: number,
	ActiveTab: string,
	OnTabSelect: (tab: string) -> (),
	OnRefresh: () -> (),
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	Tab bar showing current tier, tokens, and commission board tabs.
	@within CommissionTabBar
	@param props TCommissionTabBarProps
	@return Instance -- React frame element
]=]
local function CommissionTabBar(props: TCommissionTabBarProps)
	local tokensDisplay = useCountUp(props.Tokens, { Duration = 0.3 })
	local tabWidth = UDim2.fromScale(0.22, 0.90909)
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

	-- Build tab buttons: "available" and "active" toggle between each other, "refresh" always has fixed purple color
	for i, tabKey in ipairs(TAB_ORDER) do
		local config = TAB_CONFIG[tabKey]
		local isActive = tabKey == props.ActiveTab
		-- Refresh tab is always shown in its purple color regardless of selection state
		if tabKey == "refresh" then
			isActive = true
		end

		tabChildren["Tab_" .. tabKey] = e(TabButton, {
			Label = config.label,
			IsActive = isActive,
			LayoutOrder = i,
			Width = tabWidth,
			ActiveGradient = config.activeGradient,
			ActiveDecoreStroke = config.activeStroke,
			ActiveLabelStrokeColor = config.labelStrokeColor,
			OnSelect = function()
				if tabKey == "refresh" then
					props.OnRefresh()
				else
					props.OnTabSelect(tabKey)
				end
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
			TierLabel = e("TextLabel", {
				Text = "Tier:",
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
				Position = UDim2.fromScale(0.05278, 0.45902),
				Size = UDim2.fromScale(0.07903, 0.4918),
			}),

			TierAmount = e("TextLabel", {
				Text = props.TierLabel,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.18, 0.45902),
				Size = UDim2.fromScale(0.09931, 0.4918),
			}),

			TokensLabel = e("TextLabel", {
				Text = "Tokens:",
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
				Position = UDim2.fromScale(0.29, 0.45902),
				Size = UDim2.fromScale(0.08556, 0.4918),
			}),

			TokensAmount = e("TextLabel", {
				Text = tokensDisplay,
				FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 25,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(0.42, 0.45902),
				Size = UDim2.fromScale(0.08222, 0.4918),
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

return CommissionTabBar
