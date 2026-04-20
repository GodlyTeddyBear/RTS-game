--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local TabButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Molecules.TabButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ShopTypes = require(script.Parent.Parent.Parent.Types.ShopTypes)

export type TShopCategoryFilter = ShopTypes.TShopCategoryFilter

-- Internal category button configuration.
type TCategoryButtonConfig = {
	Key: TShopCategoryFilter,
	Label: string,
}

--[=[
	@interface TShopFooterProps
	Props for the Shop footer.
	.Position UDim2? -- Optional position override
	.AnchorPoint Vector2? -- Optional anchor point override
	.ActiveCategory TShopCategoryFilter -- Currently active category filter
	.OnCategorySelect (category: TShopCategoryFilter) -> () -- Category selection callback
]=]
export type TShopFooterProps = {
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ActiveCategory: TShopCategoryFilter,
	OnCategorySelect: (category: TShopCategoryFilter) -> (),
}

-- Category filter buttons in render order.
local CATEGORY_BUTTONS: { TCategoryButtonConfig } = {
	{ Key = "All", Label = "All" },
	{ Key = "Material", Label = "Materials" },
	{ Key = "Weapon", Label = "Weapons" },
	{ Key = "Armor", Label = "Armor" },
	{ Key = "Accessory", Label = "Accessories" },
	{ Key = "Consumable", Label = "Consumables" },
	{ Key = "Cosmetic", Label = "Cosmetics" },
	{ Key = "Building", Label = "Buildings" },
	{ Key = "Misc", Label = "Misc" },
}

--[=[
	@class ShopFooter
	Footer bar with horizontally scrollable category filter buttons.
	@client
]=]

--[=[
	Render the Shop footer with category filter buttons.
	@within ShopFooter
	@param props TShopFooterProps
	@return React.ReactElement -- Footer component
]=]
-- Stable per-category OnSelect callbacks, memoized against the callback reference.
local function _makeCategoryCallbacks(
	onCategorySelect: (category: TShopCategoryFilter) -> ()
): { [string]: () -> () }
	local callbacks: { [string]: () -> () } = {}
	for _, config in ipairs(CATEGORY_BUTTONS) do
		local key = config.Key
		callbacks[key] = function()
			onCategorySelect(key)
		end
	end
	return callbacks
end

local BUTTON_WIDTH_OFFSET = UDim2.fromOffset(140, 0)

local function ShopFooter(props: TShopFooterProps)
	local categoryCallbacks = React.useMemo(function()
		return _makeCategoryCallbacks(props.OnCategorySelect)
	end, { props.OnCategorySelect :: any })

	local categoryChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
		}),
	}

	for i, categoryConfig in ipairs(CATEGORY_BUTTONS) do
		categoryChildren["Category_" .. categoryConfig.Key] = e(TabButton, {
			Label = categoryConfig.Label,
			IsActive = props.ActiveCategory == categoryConfig.Key,
			LayoutOrder = i,
			Width = BUTTON_WIDTH_OFFSET,
			ActiveGradient = GradientTokens.TAB_ACTIVE_GRADIENT,
			ActiveDecoreStroke = GradientTokens.TAB_ACTIVE_STROKE,
			ActiveLabelStrokeColor = GradientTokens.CATEGORY_TAB_LABEL_STROKE_COLOR,
			GradientRotation = -141,
			FontFamily = "rbxasset://fonts/families/GothamSSm.json",
			OnSelect = categoryCallbacks[categoryConfig.Key],
		})
	end

	return e(Frame, {
		Size = UDim2.fromScale(1, 0.08105),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		LayoutOrder = 4,
		ClipsDescendants = true,
		ZIndex = 0,
		children = {
			CategoryScroll = e("ScrollingFrame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				AutomaticCanvasSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				CanvasSize = UDim2.new(),
				ScrollingDirection = Enum.ScrollingDirection.X,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.985, 0.9),
				ScrollBarImageColor3 = GradientTokens.GOLD_SCROLLBAR_COLOR,
				ScrollBarThickness = 4,
				VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			}, categoryChildren),
		},
	})
end

return ShopFooter
