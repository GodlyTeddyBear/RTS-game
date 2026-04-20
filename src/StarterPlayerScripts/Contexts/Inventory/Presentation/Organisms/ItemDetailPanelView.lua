--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local InventorySlotViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.InventorySlotViewModel)

local ActionButton = require(script.Parent.Parent.Molecules.ActionButton)
local ItemIconDisplay = require(script.Parent.Parent.Molecules.ItemIconDisplay)
local ItemMetaLabels = require(script.Parent.Parent.Molecules.ItemMetaLabels)

local GRADIENT_ROTATION = -141

--[=[
	@interface TItemDetailPanelViewProps
	@within ItemDetailPanelView
	.Item InventorySlotViewModel? -- Selected item or nil
	.ShouldRenderEmpty boolean -- Show empty state
	.EmptyContainerRef { current: Frame? } -- Empty state container
	.ContentRef { current: Frame? } -- Content container
	.ActionButtonRef { current: TextButton? } -- Action button
	.OnActionMouseEnter () -> () -- Hover enter handler
	.OnActionMouseLeave () -> () -- Hover leave handler
	.OnActionActivated () -> () -- Button activated handler
]=]
export type TItemDetailPanelViewProps = {
	Item: InventorySlotViewModel.TInventorySlotViewModel?,
	ShouldRenderEmpty: boolean,
	EmptyContainerRef: { current: Frame? },
	ContentRef: { current: Frame? },
	ActionButtonRef: { current: TextButton? },
	OnActionMouseEnter: () -> (),
	OnActionMouseLeave: () -> (),
	OnActionActivated: () -> (),
}

-- Shared outer panel shell (position + stroke) used by both states
local function _PanelShell(ref: { current: Frame? }?, children: { [string]: any })
	local shellChildren: { [string]: any } = {
		UIStroke = e("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Color = Color3.new(1, 1, 1),
			LineJoinMode = Enum.LineJoinMode.Miter,
			Thickness = 3,
		}, {
			UIGradient = e("UIGradient", {
				Color = GradientTokens.GOLD_STROKE_SUBTLE,
				Rotation = -180,
			}),
		}),
	}

	for key, child in children do
		shellChildren[key] = child
	end

	return e("Frame", {
		ref = ref,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.new(0.97847, 3, 0.5, 0),
		Size = UDim2.new(0.28681, 6, 0.96154, 6),
	}, shellChildren)
end

-- Empty placeholder shown during transition animation
local function _RenderEmptyState(containerRef: { current: Frame? })
	return _PanelShell(containerRef, {
		PlaceholderText = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Body,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.1),
			Text = "Select an item to view details",
			TextColor3 = ColorTokens.Text.OnLight,
			TextSize = 18,
			TextWrapped = true,
		}),
	})
end

--[=[
	@function ItemDetailPanelView
	@within ItemDetailPanelView
	Render item details: icon, stats, description, and action button.
	@param props TItemDetailPanelViewProps
	@return React.ReactElement?
]=]
local function ItemDetailPanelView(props: TItemDetailPanelViewProps)
	if props.ShouldRenderEmpty then
		return _RenderEmptyState(props.EmptyContainerRef)
	end

	local item = props.Item
	if not item then
		return nil
	end

	return _PanelShell(nil, {
		SlotButton = e("TextButton", {
			ref = props.ContentRef,
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

			MetaLabels = e(ItemMetaLabels, {
				Rarity = item.Rarity,
				RarityColor = item.RarityColor,
				Category = item.Category,
				IsStackable = item.IsStackable,
				MaxStack = item.MaxStack,
			}),

			Icon = e(ItemIconDisplay, {
				ItemIcon = item.ItemIcon,
				NameAbbr = item.NameAbbr,
				Position = UDim2.fromScale(0.50127, 0.36662),
				Size = UDim2.new(0.72774, 12, 0.39124, 12),
				StrokeColor = GradientTokens.DETAIL_ICON_STROKE,
				StrokeThickness = 6,
			}),

			Label = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				FontFace = TypographyTokens.FontFace.Bold,
				Interactable = false,
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

			DescriptionContainer = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
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

			OptionsContainer = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				ClipsDescendants = true,
				Position = UDim2.fromScale(0.50127, 0.96033),
				Size = UDim2.fromScale(0.83969, 0.09166),
			}, {
				OptionButton = e(ActionButton, {
					Label = "Action",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.37576, 0.76119),
					ButtonRef = props.ActionButtonRef,
					OnMouseEnter = props.OnActionMouseEnter,
					OnMouseLeave = props.OnActionMouseLeave,
					OnActivated = props.OnActionActivated,
				}),
			}),
		}),
	})
end

return ItemDetailPanelView
