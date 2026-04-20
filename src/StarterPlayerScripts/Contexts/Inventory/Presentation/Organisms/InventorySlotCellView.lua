--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local InventorySlotViewModel =
	require(script.Parent.Parent.Parent.Application.ViewModels.InventorySlotViewModel)

local GRADIENT_ROTATION = -141

--[=[
	@interface TInventorySlotCellViewProps
	@within InventorySlotCellView
	.Item InventorySlotViewModel -- Slot data
	.LayoutOrder number? -- Grid order
	.ButtonRef { current: TextButton? } -- Button element
	.OnMouseEnter () -> () -- Hover enter
	.OnMouseLeave () -> () -- Hover leave
	.OnActivated () -> () -- Click handler
	.IsSelected boolean -- Selection state
	.DecoreStroke ColorSequence -- Decoration stroke
	.ItemIcon string? -- Icon path or nil
	.NameAbbr string -- Item abbreviation
	.ShowQuantity boolean -- Show quantity badge
]=]
export type TInventorySlotCellViewProps = {
	Item: InventorySlotViewModel.TInventorySlotViewModel,
	LayoutOrder: number?,
	ButtonRef: { current: TextButton? },
	OnMouseEnter: () -> (),
	OnMouseLeave: () -> (),
	OnActivated: () -> (),
	IsSelected: boolean,
	DecoreStroke: ColorSequence,
	ItemIcon: string?,
	NameAbbr: string,
	ShowQuantity: boolean,
}

--[=[
	@function InventorySlotCellView
	@within InventorySlotCellView
	Render a single inventory slot. Empty slots show a plain placeholder decore;
	occupied slots show the item icon, name label, and optional quantity badge.
	@param props TInventorySlotCellViewProps
	@return React.ReactElement
]=]
local function InventorySlotCellView(props: TInventorySlotCellViewProps)
	local isEmpty = props.Item.IsEmpty

	local decore = if isEmpty
		then e(Frame, {
			Size = UDim2.new(0.9, 6, 0.9, 6),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			CornerRadius = UDim.new(),
			StrokeColor = GradientTokens.SLOT_DECORE_STROKE,
			StrokeThickness = 2,
			StrokeMode = Enum.ApplyStrokeMode.Border,
		})
		else e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.9, 6, 0.9, 6),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = if props.IsSelected then 4 else 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = props.DecoreStroke,
					Rotation = -44,
				}),
			}),
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(),
			}),
		})

	return e("TextButton", {
		ref = props.ButtonRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if isEmpty then 0.3 else 0,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		Text = "",
		TextSize = 1,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = props.OnMouseEnter,
		[React.Event.MouseLeave] = props.OnMouseLeave,
		[React.Event.Activated] = props.OnActivated,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.SLOT_GRADIENT,
			Rotation = GRADIENT_ROTATION,
		}),
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 9),
		}),
		Decore = decore,

		Label = if not isEmpty
			then e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Bold,
				Interactable = false,
				Position = UDim2.new(0.5, 0, 0.9, 5),
				Size = UDim2.new(0.9, 9, 0.12, 9),
				Text = props.Item.ItemName or "",
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 22,
				TextWrapped = true,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}, {
				UIStroke = e("UIStroke", {
					Color = Color3.fromRGB(4, 4, 4),
					LineJoinMode = Enum.LineJoinMode.Miter,
					Thickness = 4.5,
				}),
			})
			else nil,

		Icon = if not isEmpty
			then e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.new(1, 1, 1),
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.5, 0.415),
				Size = UDim2.fromScale(0.68, 0.51),
			}, {
				UIGradient = e("UIGradient", {
					Color = GradientTokens.SLOT_ICON_GRADIENT,
					Rotation = GRADIENT_ROTATION,
				}),
				UICorner = e("UICorner"),
				IconImage = if props.ItemIcon
					then e("ImageLabel", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						Image = props.ItemIcon,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.85, 0.85),
						ScaleType = Enum.ScaleType.Fit,
					})
					else nil,
				IconText = if not props.ItemIcon
					then e("TextLabel", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = props.NameAbbr,
						TextColor3 = ColorTokens.Text.Muted,
						TextScaled = true,
						FontFace = TypographyTokens.FontFace.Bold,
					})
					else nil,
			})
			else nil,

		Amount = if props.ShowQuantity
			then e("TextLabel", {
				ZIndex = 2,
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Body,
				Interactable = false,
				Position = UDim2.fromScale(0.95333, 0.04667),
				Size = UDim2.fromScale(0.29333, 0.14667),
				Text = "x" .. tostring(props.Item.Quantity),
				TextColor3 = Color3.new(1, 1, 1),
				TextSize = 18,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			else nil,
	})
end

return InventorySlotCellView
