--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local Knit = require(ReplicatedStorage.Packages.Knit)

local useState = React.useState
local useEffect = React.useEffect

local useGold = require(script.Parent.useGold)
local useShopInventory = require(script.Parent.useShopInventory)
local useShopActions = require(script.Parent.useShopActions)
local useShopSounds = require(script.Parent.Sounds.useShopSounds)
local useNavigationActions = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useNavigationActions)
local useUnlockState = require(script.Parent.Parent.Parent.Parent.Unlock.Application.Hooks.useUnlockState)
local useCountUp = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useCountUp)
local ShopSlotViewModel = require(script.Parent.Parent.ViewModels.ShopSlotViewModel)
local ShopTypes = require(script.Parent.Parent.Parent.Types.ShopTypes)

export type TShopCategoryFilter = ShopTypes.TShopCategoryFilter

--[=[
	@interface TShopScreenController
	@within useShopScreenController
	Complete screen state and callbacks for the Shop UI.
	.gold number -- Current gold amount
	.activeTab "buy" | "sell" -- Currently active tab
	.activeCategory TShopCategoryFilter -- Currently active category filter
	.selectedItem ShopSlotViewModel.TShopSlotViewModel? -- Currently selected item or nil
	.quantity number -- Current quantity selection (1-99)
	.maxQuantity number -- Maximum quantity allowed (seller's stock or 99 for buy)
	.totalCost number -- unitPrice * quantity
	.gridItems { ShopSlotViewModel.TShopSlotViewModel } -- Filtered grid for active tab and category
	.onBack () -> () -- Navigate back
	.onTabSelect (tab: "buy" | "sell") -> () -- Switch between buy/sell
	.onCategorySelect (category: TShopCategoryFilter) -> () -- Filter by category
	.onSelectItem (item: ShopSlotViewModel.TShopSlotViewModel) -> () -- Select an item
	.onIncrement () -> () -- Increase quantity (capped at maxQuantity)
	.onDecrement () -> () -- Decrease quantity (floored at 1)
	.goldDisplay string -- Animated gold display string (e.g. "1 234 Gold")
	.onBuy () -> () -- Execute purchase of selected item at current quantity
	.onSell () -> () -- Execute sale of selected item at current quantity
]=]
export type TShopScreenController = {
	gold: number,
	goldDisplay: string,
	activeTab: "buy" | "sell",
	activeCategory: TShopCategoryFilter,
	selectedItem: ShopSlotViewModel.TShopSlotViewModel?,
	quantity: number,
	maxQuantity: number,
	totalCost: number,
	gridItems: { ShopSlotViewModel.TShopSlotViewModel },
	onBack: () -> (),
	onTabSelect: (tab: "buy" | "sell") -> (),
	onCategorySelect: (category: TShopCategoryFilter) -> (),
	onSelectItem: (item: ShopSlotViewModel.TShopSlotViewModel) -> (),
	onIncrement: () -> (),
	onDecrement: () -> (),
	onBuy: () -> (),
	onSell: () -> (),
}

-- Filter grid by category name. Unmapped categories resolve to "Misc".
local function _filterGrid(
	allItems: { ShopSlotViewModel.TShopSlotViewModel },
	category: TShopCategoryFilter
): { ShopSlotViewModel.TShopSlotViewModel }
	if category == "All" then
		return allItems
	end
	local filtered: { ShopSlotViewModel.TShopSlotViewModel } = {}
	for _, vm in ipairs(allItems) do
		if ShopSlotViewModel.resolveCategoryFilter(vm.Category) == category then
			table.insert(filtered, vm)
		end
	end
	return table.freeze(filtered)
end

--[=[
	@function useShopScreenController
	@within useShopScreenController
	Aggregate all Shop screen state (tabs, categories, selection, quantity, grid) and expose unified callbacks.
	Handles hydration, tab resets, and clearing stale selections when items are removed from the grid.
	@return TShopScreenController
]=]
local function useShopScreenController(): TShopScreenController
	local gold = useGold()
	local goldDisplay = useCountUp(gold, { Duration = 0.3, Suffix = " Gold" })
	local inventoryState = useShopInventory()
	local unlockState = useUnlockState()
	local shopActions = useShopActions()
	local sounds = useShopSounds()
	local navActions = useNavigationActions()

	local activeTab, setActiveTab = useState("buy" :: "buy" | "sell")
	local activeCategory, setActiveCategory = useState("All" :: TShopCategoryFilter)
	local selectedItem, setSelectedItem = useState(nil :: ShopSlotViewModel.TShopSlotViewModel?)
	local quantity, setQuantity = useState(1)

	-- Hydrate gold and unlock state on mount
	useEffect(function()
		local shopController = Knit.GetController("ShopController")
		if shopController then
			shopController:RequestGoldState()
		end

		local unlockController = Knit.GetController("UnlockController")
		if unlockController then
			unlockController:RequestUnlockState()
		end
	end, {})

	-- Reset selection, quantity, and category when tab changes
	useEffect(function()
		setActiveCategory("All")
		setSelectedItem(nil)
		setQuantity(1)
	end, { activeTab } :: { any })

	-- Reset quantity when selected item changes
	useEffect(function()
		setQuantity(1)
	end, { selectedItem } :: { any })

	-- Build grid for active tab
	local allGridItems = if activeTab == "buy"
		then ShopSlotViewModel.buildBuyGrid(gold, unlockState)
		else ShopSlotViewModel.buildSellGrid(inventoryState)
	local gridItems = _filterGrid(allGridItems, activeCategory)

	-- Clear selection if the selected item is no longer in the grid (e.g. fully sold)
	useEffect(function()
		if selectedItem == nil then
			return
		end
		local found = false
		for _, vm in ipairs(gridItems) do
			if vm.ItemId == selectedItem.ItemId and vm.SlotIndex == selectedItem.SlotIndex then
				found = true
				break
			end
		end
		if not found then
			setSelectedItem(nil)
		end
	end, { gridItems } :: { any })

	local maxQuantity = if activeTab == "sell" and selectedItem then selectedItem.Quantity else 99
	local unitPrice = if selectedItem
		then (if activeTab == "buy" then selectedItem.BuyPrice else selectedItem.SellPrice)
		else 0
	local totalCost = unitPrice * quantity

	local function onBack()
		sounds.onBack()
		navActions.goBack()
	end

	local function onTabSelect(tab: "buy" | "sell")
		sounds.onTabSwitch(tab)
		setActiveTab(tab)
	end

	local function onCategorySelect(category: TShopCategoryFilter)
		sounds.onTabSwitch(category)
		setActiveCategory(category)
	end

	local function onSelectItem(item: ShopSlotViewModel.TShopSlotViewModel)
		setSelectedItem(item)
	end

	local function onIncrement()
		setQuantity(function(prev)
			return math.min(maxQuantity, prev + 1)
		end)
	end

	local function onDecrement()
		setQuantity(function(prev)
			return math.max(1, prev - 1)
		end)
	end

	local function onBuy()
		if selectedItem then
			sounds.onBuy()
			shopActions.buyItem(selectedItem.ItemId, quantity)
			setQuantity(1)
		end
	end

	local function onSell()
		if selectedItem then
			sounds.onSell()
			shopActions.sellItem(selectedItem.SlotIndex, quantity)
			setQuantity(1)
		end
	end

	return {
		gold = gold,
		goldDisplay = goldDisplay,
		activeTab = activeTab,
		activeCategory = activeCategory :: TShopCategoryFilter,
		selectedItem = selectedItem,
		quantity = quantity,
		maxQuantity = maxQuantity,
		totalCost = totalCost,
		gridItems = gridItems,
		onBack = onBack,
		onTabSelect = onTabSelect,
		onCategorySelect = onCategorySelect,
		onSelectItem = onSelectItem,
		onIncrement = onIncrement,
		onDecrement = onDecrement,
		onBuy = onBuy,
		onSell = onSell,
	}
end

return useShopScreenController
