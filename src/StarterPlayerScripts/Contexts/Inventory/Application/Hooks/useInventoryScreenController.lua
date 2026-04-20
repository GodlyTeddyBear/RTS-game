--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useState = React.useState
local useCallback = React.useCallback

local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useInventoryState = require(script.Parent.useInventoryState)
local useInventorySounds = require(script.Parent.Sounds.useInventorySounds)
local InventorySlotViewModel = require(script.Parent.Parent.ViewModels.InventorySlotViewModel)

local CategoryConfig = require(ReplicatedStorage.Contexts.Inventory.Config.CategoryConfig)

type TTabInfo = {
	Name: string,
	Count: number,
	DisplayOrder: number,
}

--[=[
	@interface TInventoryScreenController
	@within useInventoryScreenController
	.usedSlots number -- Number of occupied slots
	.totalSlots number -- Total available slots
	.tabInfo { TTabInfo } -- Category tabs with item counts
	.activeTab string -- Currently selected tab name
	.gridItems { InventorySlotViewModel } -- Items to display in grid (all or filtered)
	.selectedItem InventorySlotViewModel? -- Currently selected item or nil
	.selectedSlotIndex number? -- Slot index of selected item or nil
	.onBack () -> () -- Navigate back handler
	.onTabSelect (tabName: string) -> () -- Tab selection handler
	.onSelectItem (item: InventorySlotViewModel) -> () -- Item selection handler
]=]
export type TInventoryScreenController = {
	usedSlots: number,
	totalSlots: number,
	tabInfo: { TTabInfo },
	activeTab: string,
	gridItems: { InventorySlotViewModel.TInventorySlotViewModel },
	selectedItem: InventorySlotViewModel.TInventorySlotViewModel?,
	selectedSlotIndex: number?,
	onBack: () -> (),
	onTabSelect: (tabName: string) -> (),
	onSelectItem: (item: InventorySlotViewModel.TInventorySlotViewModel) -> (),
}

-- Build sorted tab list once at module level.
local TABS: { { Name: string, DisplayOrder: number } } = {
	{ Name = "All", DisplayOrder = 0 },
}
for categoryName, settings in pairs(CategoryConfig) do
	table.insert(TABS, { Name = categoryName, DisplayOrder = settings.displayOrder })
end
table.sort(TABS, function(a, b)
	return a.DisplayOrder < b.DisplayOrder
end)

-- Builds tab info with item counts for each category
local function _BuildTabInfo(inventoryState): { TTabInfo }
	local tabInfo: { TTabInfo } = {}
	for _, tab in ipairs(TABS) do
		local count = InventorySlotViewModel.getFilteredCount(inventoryState, tab.Name)
		table.insert(tabInfo, {
			Name = tab.Name,
			Count = count,
			DisplayOrder = tab.DisplayOrder,
		})
	end
	return tabInfo
end

--[=[
	@function useInventoryScreenController
	@within useInventoryScreenController
	Manage inventory screen state: tabs, filtering, selection, and navigation.
	@return TInventoryScreenController
]=]
local function useInventoryScreenController(): TInventoryScreenController
	local inventoryState = useInventoryState()
	local navActions = useNavigationActions()
	local sounds = useInventorySounds()
	local activeTab, setActiveTab = useState("All" :: string)
	local selectedItem, setSelectedItem = useState(nil :: InventorySlotViewModel.TInventorySlotViewModel?)

	local usedSlots = if inventoryState then inventoryState.Metadata.UsedSlots else 0
	local totalSlots = if inventoryState then inventoryState.Metadata.TotalSlots else 200
	local gridItems = InventorySlotViewModel.buildGrid(inventoryState, activeTab)
	local tabInfo = _BuildTabInfo(inventoryState)
	local selectedSlotIndex = if selectedItem and not selectedItem.IsEmpty then selectedItem.SlotIndex else nil

	local onBack = useCallback(function()
		sounds.onBack()
		navActions.goBack()
	end, { sounds, navActions } :: { any })

	local onTabSelect = useCallback(function(tabName: string)
		sounds.onTabSwitch(tabName)
		setActiveTab(tabName)
	end, { sounds, setActiveTab } :: { any })

	local onSelectItem = useCallback(function(clickedItem: InventorySlotViewModel.TInventorySlotViewModel)
		if not clickedItem.IsEmpty then
			setSelectedItem(clickedItem)
		end
	end, { setSelectedItem } :: { any })

	return {
		usedSlots = usedSlots,
		totalSlots = totalSlots,
		tabInfo = tabInfo,
		activeTab = activeTab,
		gridItems = gridItems,
		selectedItem = selectedItem,
		selectedSlotIndex = selectedSlotIndex,
		onBack = onBack,
		onTabSelect = onTabSelect,
		onSelectItem = onSelectItem,
	}
end

return useInventoryScreenController
