--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

local ShopHeader = require(script.Parent.Parent.Organisms.ShopHeader)
local ShopTabBar = require(script.Parent.Parent.Organisms.ShopTabBar)
local ShopDetailPanel = require(script.Parent.Parent.Organisms.ShopDetailPanel)
local ShopFooter = require(script.Parent.Parent.Organisms.ShopFooter)

--[=[
	@interface TShopScreenViewProps
	Complete props for rendering the Shop screen view.
	.containerRef { current: Frame? } -- Container frame ref for screen transitions
	.grid React.ReactElement -- Pre-built ShopGrid element
	.onBack () -> () -- Navigate back
	.goldDisplay string -- Pre-animated gold display string for the tab bar
	.activeTab string -- "buy" or "sell"
	.onTabSelect (tab: string) -> () -- Tab selection callback
	.selectedItem any -- Currently selected grid item or nil
	.quantity number -- Current quantity selection
	.totalCost number -- Calculated cost (for display)
	.onBuy () -> () -- Execute purchase
	.onSell () -> () -- Execute sale
	.onIncrement () -> () -- Increase quantity
	.onDecrement () -> () -- Decrease quantity
	.activeCategory string -- Current category filter
	.onCategorySelect (category: string) -> () -- Category filter callback
]=]
type TShopScreenViewProps = {
	containerRef: { current: Frame? },
	grid: any,
	onBack: () -> (),
	goldDisplay: string,
	activeTab: string,
	onTabSelect: (tab: string) -> (),
	selectedItem: any,
	quantity: number,
	totalCost: number,
	onBuy: () -> (),
	onSell: () -> (),
	onIncrement: () -> (),
	onDecrement: () -> (),
	activeCategory: string,
	onCategorySelect: (category: string) -> (),
}

--[=[
	@class ShopScreenView
	Presentational layout component that renders the Shop UI structure (header, tabs, grid, detail panel, footer).
	@client
]=]

--[=[
	Render the Shop screen layout with grid and detail panels.
	@within ShopScreenView
	@param props TShopScreenViewProps
	@return React.ReactElement -- Shop screen layout
]=]
local function ShopScreenView(props: TShopScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Header = e(ShopHeader, {
			Position = UDim2.fromScale(0.5, 0.049),
			OnBack = props.onBack,
		}),
		TabBar = e(ShopTabBar, {
			Position = UDim2.fromScale(0.5, 0.12779),
			GoldDisplay = props.goldDisplay,
			ActiveTab = props.activeTab,
			OnTabSelect = props.onTabSelect,
		}),
		Content = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.53826),
			Size = UDim2.fromScale(1, 0.76172),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.LIST_CONTAINER_GRADIENT,
			GradientRotation = -16,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			ClipsDescendants = true,
			children = {
				Grid = props.grid,
				DetailPanel = e(ShopDetailPanel, {
					Item = props.selectedItem,
					ActiveTab = props.activeTab,
					Quantity = props.quantity,
					TotalCost = props.totalCost,
					OnBuy = props.onBuy,
					OnSell = props.onSell,
					OnIncrement = props.onIncrement,
					OnDecrement = props.onDecrement,
				}),
			},
		}),
		Footer = e(ShopFooter, {
			Position = UDim2.fromScale(0.5, 0.95948),
			ActiveCategory = props.activeCategory,
			OnCategorySelect = props.onCategorySelect,
		}),
	})
end

return ShopScreenView
