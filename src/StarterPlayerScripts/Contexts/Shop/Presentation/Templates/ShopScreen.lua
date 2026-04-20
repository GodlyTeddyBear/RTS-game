--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useShopScreenController = require(script.Parent.Parent.Parent.Application.Hooks.useShopScreenController)

local ShopGrid = require(script.Parent.Parent.Organisms.ShopGrid)
local ShopScreenView = require(script.Parent.ShopScreenView)

--[=[
	@class ShopScreen
	Top-level template for the Shop screen. Aggregates controller logic and delegates rendering to ShopScreenView.
	@client
]=]

--[=[
	Render the Shop screen with buy/sell tabs, item grid, and detail panel.
	@within ShopScreen
	@return React.ReactElement -- Shop screen component
]=]
local function ShopScreen()
	local anim = useScreenTransition("Standard")
	local ctrl = useShopScreenController()

	return e(ShopScreenView, {
		containerRef = anim.containerRef,
		grid = e(ShopGrid, {
			GridItems = ctrl.gridItems,
			SelectedItem = ctrl.selectedItem,
			ActiveTab = ctrl.activeTab,
			OnSelectItem = ctrl.onSelectItem,
		}),
		onBack = ctrl.onBack,
		goldDisplay = ctrl.goldDisplay,
		activeTab = ctrl.activeTab,
		onTabSelect = ctrl.onTabSelect,
		selectedItem = ctrl.selectedItem,
		quantity = ctrl.quantity,
		totalCost = ctrl.totalCost,
		onBuy = ctrl.onBuy,
		onSell = ctrl.onSell,
		onIncrement = ctrl.onIncrement,
		onDecrement = ctrl.onDecrement,
		activeCategory = ctrl.activeCategory,
		onCategorySelect = ctrl.onCategorySelect,
	})
end

return ShopScreen
