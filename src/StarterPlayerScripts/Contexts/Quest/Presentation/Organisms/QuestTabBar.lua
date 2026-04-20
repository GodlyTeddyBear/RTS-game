--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local TabButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Molecules.TabButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

-- Tier filter options in order
local TIER_ORDER = { "all", "apprentice", "journeyman", "expert" }

-- Human-readable labels for tier filters
local TIER_LABELS = {
	all = "All",
	apprentice = "Apprentice",
	journeyman = "Journeyman",
	expert = "Expert",
}

--[=[
	@interface TQuestTabBarProps
	Props for the quest tab bar component.
	@within QuestTabBar
	.ActiveTier string -- Currently selected tier filter key
	.OnTierSelect (tier: string) -> () -- Called when user selects a tier tab
	.ExpeditionStatusLabel string? -- Optional label for active expedition status button
	.OnViewExpedition (() -> ())? -- Optional callback when expedition status button is clicked
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
]=]
export type TQuestTabBarProps = {
	ActiveTier: string,
	OnTierSelect: (tier: string) -> (),
	ExpeditionStatusLabel: string?,
	OnViewExpedition: (() -> ())?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

--[=[
	@class QuestTabBar
	Tab bar component for filtering quests by difficulty tier.
	Optionally displays an expedition status button on the left.
	@client
]=]
local function QuestTabBar(props: TQuestTabBarProps)
	local expeditionBtnRef = useRef(nil :: TextButton?)
	local expeditionHover = useHoverSpring(expeditionBtnRef, AnimationTokens.Interaction.ActionButton)

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

	for i, tierKey in ipairs(TIER_ORDER) do
		tabChildren["Tab_" .. tierKey] = e(TabButton, {
			Label = TIER_LABELS[tierKey] or tierKey,
			IsActive = tierKey == props.ActiveTier,
			LayoutOrder = i,
			Width = UDim2.fromScale(0.22, 0.90909),
			ActiveGradient = GradientTokens.TAB_ACTIVE_GRADIENT,
			ActiveDecoreStroke = GradientTokens.TAB_ACTIVE_STROKE,
			ActiveLabelStrokeColor = Color3.fromRGB(36, 29, 0),
			OnSelect = function()
				props.OnTierSelect(tierKey)
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
			-- Expedition status button (conditional, left side)
			ExpeditionStatus = if props.ExpeditionStatusLabel
				then e("TextButton", {
					ref = expeditionBtnRef,
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.new(1, 1, 1),
					ClipsDescendants = true,
					Position = UDim2.fromScale(0.02, 0.5),
					Size = UDim2.fromScale(0.18, 0.72131),
					Text = "",
					TextSize = 1,
					[React.Event.MouseEnter] = expeditionHover.onMouseEnter,
					[React.Event.MouseLeave] = expeditionHover.onMouseLeave,
					[React.Event.Activated] = expeditionHover.onActivated(function()
						if props.OnViewExpedition then
							props.OnViewExpedition()
						end
					end),
				}, {
					UIGradient = e("UIGradient", {
						Color = GradientTokens.ASSIGN_BUTTON_GRADIENT,
						Rotation = -4,
					}),
					UICorner = e("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),
					Label = e("TextLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothicA1.json",
							Enum.FontWeight.Bold,
							Enum.FontStyle.Normal
						),
						Interactable = false,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.9, 0.75),
						Text = props.ExpeditionStatusLabel,
						TextColor3 = Color3.new(1, 1, 1),
						TextSize = 14,
						TextWrapped = true,
					}, {
						UIStroke = e("UIStroke", {
							Color = Color3.fromRGB(96, 2, 4),
							LineJoinMode = Enum.LineJoinMode.Miter,
							Thickness = 2,
						}),
					}),
				})
				else nil,

			-- Tab container (right side)
			Container = e("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.98, 0.5),
				Size = UDim2.fromScale(0.55, 0.72131),
			}, tabChildren),
		},
	})
end

return QuestTabBar
