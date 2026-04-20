--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

local ActionButton = require(script.Parent.ActionButton)
local ItemIconDisplay = require(script.Parent.Parent.Molecules.ItemIconDisplay)
local QuantitySelector = require(script.Parent.Parent.Molecules.QuantitySelector)
local ShopSlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ShopSlotViewModel)

-- Gradient rotation angle for detail panel styling.
local GRADIENT_ROTATION = -141

--[=[
	@interface TShopDetailPanelViewProps
	Props for the pure detail panel render tree.
	.item ShopSlotViewModel.TShopSlotViewModel -- Selected item (non-nil; empty state is rendered by the wrapper)
	.isBuyTab boolean -- Whether the buy tab is active
	.quantity number -- Current quantity selection
	.animatedCost string -- Pre-animated cost display string
	.contentRef { current: TextButton? } -- Ref for the inner slot button
	.addBtnRef { current: TextButton? } -- Ref for the increment button
	.minusBtnRef { current: TextButton? } -- Ref for the decrement button
	.addHover table -- Hover spring callbacks for increment button
	.minusHover table -- Hover spring callbacks for decrement button
	.onBuy () -> () -- Buy action callback
	.onSell () -> () -- Sell action callback
	.onIncrement () -> () -- Increase quantity callback
	.onDecrement () -> () -- Decrease quantity callback
]=]
export type TShopDetailPanelViewProps = {
	item: ShopSlotViewModel.TShopSlotViewModel,
	isBuyTab: boolean,
	quantity: number,
	animatedCost: string,
	contentRef: { current: TextButton? },
	addBtnRef: { current: TextButton? },
	minusBtnRef: { current: TextButton? },
	addHover: any,
	minusHover: any,
	onBuy: () -> (),
	onSell: () -> (),
	onIncrement: () -> (),
	onDecrement: () -> (),
}

--[=[
	@class ShopDetailPanelView
	Pure render tree for the Shop detail panel. No animation orchestration — all motion values and refs arrive as props.
	@client
]=]

--[=[
	Render the detail panel content for a selected shop item.
	@within ShopDetailPanelView
	@param props TShopDetailPanelViewProps
	@return React.ReactElement -- Detail panel content
]=]
local function ShopDetailPanelView(props: TShopDetailPanelViewProps)
	local item = props.item
	local itemIcon = item.ItemIcon

	return e("TextButton", {
		ref = props.contentRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = UDim2.fromScale(0.5, 0.49933),
		Size = UDim2.fromScale(0.95157, 0.97467),
		Text = "",
		TextSize = 1,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.SLOT_GRADIENT,
			Rotation = GRADIENT_ROTATION,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 9),
		}),

		Decore = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.9542, 6, 0.97538, 6),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.SLOT_DECORE_STROKE,
					Rotation = -44,
				}),
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(),
			}),
		}),

		-- Rarity label (top-left)
		Rarity = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			Interactable = false,
			Position = UDim2.new(0.4771, 0, 0.02326, -4),
			Size = UDim2.new(0.77608, 8, 0.04514, 8),
			Text = item.Rarity or "Common",
			TextColor3 = item.RarityColor or Color3.new(1, 1, 1),
			TextSize = 37,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.new(1, 1, 1),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4,
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.SLOT_GRADIENT,
					Rotation = GRADIENT_ROTATION,
				}),
			}),
		}),

		-- Category label
		Category = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			Interactable = false,
			LayoutOrder = 4,
			Position = UDim2.fromScale(0.26972, 0.07524),
			Size = UDim2.fromScale(0.36132, 0.0301),
			Text = item.Category or "Unknown",
			TextColor3 = ColorTokens.Text.OnLight,
			TextSize = 16,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		-- Stackable info
		Stackable = if item.StackableLabel
			then e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Body,
				Interactable = false,
				LayoutOrder = 5,
				Position = UDim2.fromScale(0.31298, 0.11218),
				Size = UDim2.fromScale(0.44784, 0.0301),
				Text = item.StackableLabel,
				TextColor3 = ColorTokens.Border.Strong,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			else nil,

		-- Icon area (centered)
		Icon = e(ItemIconDisplay, {
			Icon = itemIcon,
			NameAbbreviation = item.NameAbbreviation,
			Position = UDim2.fromScale(0.50127, 0.36662),
			Size = UDim2.new(0.72774, 12, 0.39124, 12),
			StrokeThickness = 6,
			StrokeGradient = GradientTokens.DETAIL_ICON_STROKE,
		}),

		-- Item name label
		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Bold,
			Interactable = false,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.50127, 0.61423),
			Size = UDim2.new(0.82443, 9, 0.06566, 9),
			Text = item.ItemName or "Unknown",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 42,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = ColorTokens.Text.OnLight,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4.5,
			}),
		}),

		-- Description container
		DescriptionContainer = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 6,
			Position = UDim2.fromScale(0.49746, 0.86047),
			Size = UDim2.fromScale(0.83206, 0.19425),
		}, {
			Description = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Body,
				Position = UDim2.fromScale(0.5, 0.50352),
				Size = UDim2.fromScale(1, 0.99296),
				Text = item.ItemDescription or "No description available.",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 21,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		}),

		-- Options container: quantity controls + action button
		OptionsContainer = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			LayoutOrder = 7,
			Position = UDim2.fromScale(0.50127, 0.96033),
			Size = UDim2.fromScale(0.83969, 0.09166),
		}, {
			-- Left: amount controls
			AmountContainer = e(QuantitySelector, {
				quantity = props.quantity,
				animatedCost = props.animatedCost,
				addBtnRef = props.addBtnRef,
				minusBtnRef = props.minusBtnRef,
				addHover = props.addHover,
				minusHover = props.minusHover,
				onIncrement = props.onIncrement,
				onDecrement = props.onDecrement,
			}),

			-- Right: action button
			ActionContainer = e("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromScale(0.42727, 0.97015),
			}, {
				ActionBtn = if props.isBuyTab
					then e(ActionButton, {
						Label = "Buy",
						Gradient = GradientTokens.GREEN_ACTION_GRADIENT,
						DecoreColor = GradientTokens.GREEN_ACTION_DECORE_COLOR,
						DecoreStrokeGradient = nil,
						LabelStrokeColor = GradientTokens.GREEN_ACTION_LABEL_STROKE_COLOR,
						LabelStrokeGradient = nil,
						GradientRotation = -3,
						OnActivated = props.onBuy,
					})
					else e(ActionButton, {
						Label = "Sell",
						Gradient = GradientTokens.ASSIGN_BUTTON_GRADIENT,
						DecoreColor = Color3.new(1, 1, 1),
						DecoreStrokeGradient = GradientTokens.ASSIGN_BUTTON_STROKE,
						LabelStrokeColor = Color3.new(1, 1, 1),
						LabelStrokeGradient = GradientTokens.ASSIGN_BUTTON_STROKE,
						GradientRotation = -4,
						OnActivated = props.onSell,
					}),
			}),
		}),
	})
end

return ShopDetailPanelView
