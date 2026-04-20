--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

local ItemIconDisplay = require(script.Parent.Parent.Molecules.ItemIconDisplay)
local ShopSlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.ShopSlotViewModel)

--[=[
	@interface TShopSlotCellProps
	Props for a single shop grid cell.
	.Item ShopSlotViewModel.TShopSlotViewModel -- Item to display
	.IsSelected boolean? -- Whether this cell is currently selected
	.OnSelect ((item: ShopSlotViewModel.TShopSlotViewModel) -> ())? -- Selection callback
	.LayoutOrder number? -- Grid layout order
]=]
export type TShopSlotCellProps = {
	Item: ShopSlotViewModel.TShopSlotViewModel,
	IsSelected: boolean?,
	OnSelect: ((item: ShopSlotViewModel.TShopSlotViewModel) -> ())?,
	LayoutOrder: number?,
}

-- Gradient rotation angle for slot styling.
local GRADIENT_ROTATION = -141

--[=[
	@class ShopSlotCell
	Grid cell displaying a single shop item with icon, name, and price badge. Supports selection state and hover animations.
	@client
]=]

--[=[
	Render a single shop grid cell with item icon, name, and price.
	@within ShopSlotCell
	@param props TShopSlotCellProps
	@return React.ReactElement -- Grid cell component
]=]
local function ShopSlotCell(props: TShopSlotCellProps)
	local item = props.Item
	local isSelected = props.IsSelected or false
	local decoreStroke = if isSelected then GradientTokens.GOLD_STROKE_SUBTLE else GradientTokens.SLOT_DECORE_STROKE

	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.SlotCell)

	return e("TextButton", {
		ref = buttonRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 1,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(function()
			if props.OnSelect then
				props.OnSelect(item)
			end
		end),
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
			Size = UDim2.new(0.9, 6, 0.9, 6),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = if isSelected then 4 else 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = decoreStroke,
					Rotation = -44,
				}),
			}),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(),
			}),
		}),

		-- Item name label at bottom
		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Bold,
			Interactable = false,
			Position = UDim2.new(0.5, 0, 0.9, 5),
			Size = UDim2.new(0.9, 9, 0.12, 9),
			Text = item.ItemName or "",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 22,
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}, {
			UIStroke = e("UIStroke", {
				Color = GradientTokens.NEAR_BLACK,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 4.5,
			}),
		}),

		Icon = e(ItemIconDisplay, {
			Icon = item.ItemIcon,
			NameAbbreviation = item.NameAbbreviation,
			Position = UDim2.fromScale(0.5, 0.415),
			Size = UDim2.fromScale(0.68, 0.51),
		}),

		-- Price badge top-right
		Amount = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			ZIndex = 2,
			FontFace = TypographyTokens.FontFace.Bold,
			Interactable = false,
			Position = UDim2.new(0.95333, 3, 0.04667, -3),
			Size = UDim2.new(0.29333, 6, 0.14667, 6),
			Text = item.DisplayPrice,
			TextColor3 = GradientTokens.GOLD_SCROLLBAR_COLOR,
			TextSize = 21,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, {
			UIStroke = e("UIStroke", {
				Color = GradientTokens.NEAR_BLACK,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 3,
			}),
		}),
	})
end

return ShopSlotCell
