--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

local useShopDetailPanelController =
	require(script.Parent.Parent.Parent.Application.Hooks.Animations.useShopDetailPanelController)
local ShopDetailPanelView = require(script.Parent.ShopDetailPanelView)
local ShopSlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ShopSlotViewModel)

--[=[
	@interface TShopDetailPanelProps
	Props for the Shop detail panel.
	.Item ShopSlotViewModel.TShopSlotViewModel? -- Selected item or nil for empty state
	.ActiveTab "buy" | "sell" -- Current tab (determines action button)
	.Quantity number -- Current quantity selection
	.TotalCost number -- unitPrice × quantity
	.OnBuy () -> () -- Buy action callback
	.OnSell () -> () -- Sell action callback
	.OnIncrement () -> () -- Increase quantity
	.OnDecrement () -> () -- Decrease quantity
]=]
export type TShopDetailPanelProps = {
	Item: ShopSlotViewModel.TShopSlotViewModel?,
	ActiveTab: "buy" | "sell",
	Quantity: number,
	TotalCost: number,
	OnBuy: () -> (),
	OnSell: () -> (),
	OnIncrement: () -> (),
	OnDecrement: () -> (),
}

-- Shared outer shell props used by both empty and populated states.
local OUTER_FRAME_PROPS = {
	AnchorPoint = Vector2.new(1, 0.5),
	BackgroundTransparency = 1,
	ClipsDescendants = true,
	LayoutOrder = 1,
	Position = UDim2.new(0.97847, 3, 0.5, 0),
	Size = UDim2.new(0.28681, 6, 0.96154, 6),
}

--[=[
	@class ShopDetailPanel
	Right-side detail panel showing selected item info, quantity controls, and buy/sell action.
	Delegates all animation orchestration to useShopDetailPanelController; renders via ShopDetailPanelView.
	@client
]=]

--[=[
	Render the Shop detail panel (empty placeholder or item content).
	@within ShopDetailPanel
	@param props TShopDetailPanelProps
	@return React.ReactElement -- Detail panel component
]=]
local function ShopDetailPanel(props: TShopDetailPanelProps)
	local ctrl = useShopDetailPanelController(props.Item, props.TotalCost)

	local outerStroke = e("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Color = Color3.new(1, 1, 1),
		LineJoinMode = Enum.LineJoinMode.Miter,
		Thickness = 3,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.GOLD_STROKE_SUBTLE,
			Rotation = -180,
		}),
	})

	if not props.Item then
		return e("Frame", OUTER_FRAME_PROPS, {
			UIStroke = outerStroke,
			PlaceholderText = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Body,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.1),
				Text = "Select an item to view details",
				TextColor3 = ColorTokens.Border.Strong,
				TextSize = 18,
				TextWrapped = true,
			}),
		})
	end

	return e("Frame", OUTER_FRAME_PROPS, {
		UIStroke = outerStroke,
		SlotButton = e(ShopDetailPanelView, {
			item = props.Item,
			isBuyTab = props.ActiveTab == "buy",
			quantity = props.Quantity,
			animatedCost = ctrl.animatedCost,
			contentRef = ctrl.contentRef,
			addBtnRef = ctrl.addBtnRef,
			minusBtnRef = ctrl.minusBtnRef,
			addHover = ctrl.addHover,
			minusHover = ctrl.minusHover,
			onBuy = props.OnBuy,
			onSell = props.OnSell,
			onIncrement = props.OnIncrement,
			onDecrement = props.OnDecrement,
		}),
	})
end

return ShopDetailPanel
