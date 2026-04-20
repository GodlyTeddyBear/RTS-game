--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useScreenTransition = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useScreenTransition)
local useInventoryScreenController = require(script.Parent.Parent.Parent.Application.Hooks.useInventoryScreenController)
local InventoryScreenView = require(script.Parent.InventoryScreenView)

--[=[
	@function InventoryScreen
	@within InventoryScreen
	Root component for the inventory screen, wiring animations and controller data to view.
	@return React.ReactElement
]=]
local function InventoryScreen()
	-- Setup screen transition animations (fade in/out)
	local anim = useScreenTransition("Standard")
	-- Get screen state: tabs, grid, selection, handlers
	local controller = useInventoryScreenController()

	return e(InventoryScreenView, {
		ContainerRef = anim.containerRef,
		UsedSlots = controller.usedSlots,
		TotalSlots = controller.totalSlots,
		TabInfo = controller.tabInfo,
		ActiveTab = controller.activeTab,
		GridItems = controller.gridItems,
		SelectedItem = controller.selectedItem,
		SelectedSlotIndex = controller.selectedSlotIndex,
		OnBack = controller.onBack,
		OnTabSelect = controller.onTabSelect,
		OnSelectItem = controller.onSelectItem,
	})
end

return InventoryScreen
