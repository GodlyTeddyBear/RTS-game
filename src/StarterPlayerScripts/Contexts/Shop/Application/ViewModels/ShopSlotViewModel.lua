--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)
local ShopItemViewModel = require(script.Parent.ShopItemViewModel)
local SellItemViewModel = require(script.Parent.SellItemViewModel)

type TUnlockState = UnlockTypes.TUnlockState

--[=[
	@interface TShopSlotViewModel
	View model for a single shop grid cell.
	.SlotIndex number -- Inventory slot (for sell) or catalog index (for buy)
	.ItemId string -- Unique item identifier
	.ItemName string -- Display name
	.ItemDescription string -- Full item description
	.ItemIcon string? -- AssetId for the item icon, or nil
	.Category string -- Item category (e.g. "Weapon", "Material")
	.Rarity string -- Rarity tier (e.g. "Legendary")
	.RarityColor Color3? -- Color associated with rarity, or nil
	.DisplayPrice string -- Formatted price string (e.g. "$100")
	.BuyPrice number -- Buy price in gold
	.SellPrice number -- Sell price in gold
	.Quantity number -- Stack quantity (0 for buy tab, actual count for sell tab)
	.MaxStack number -- Maximum stack size
	.IsStackable boolean -- Whether the item stacks
	.IsEmpty boolean -- Whether the slot is empty
	.NameAbbreviation string -- First two characters of ItemName uppercased (fallback icon label)
	.StackableLabel string? -- Formatted "Stackable (max N)" string, or nil when not stackable
]=]
export type TShopSlotViewModel = {
	SlotIndex: number,
	ItemId: string,
	ItemName: string,
	ItemDescription: string,
	ItemIcon: string?,
	Category: string,
	Rarity: string,
	RarityColor: Color3?,
	DisplayPrice: string,
	BuyPrice: number,
	SellPrice: number,
	Quantity: number,
	MaxStack: number,
	IsStackable: boolean,
	IsEmpty: boolean,
	NameAbbreviation: string,
	StackableLabel: string?,
}

-- Derive the two-letter fallback abbreviation used when an icon is absent.
local function _nameAbbr(name: string?): string
	if not name or name == "" then
		return "?"
	end
	return string.sub(name, 1, 2):upper()
end

-- Rarity tiers mapped to their display colors.
local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(150, 150, 150),
	Uncommon = Color3.fromRGB(100, 255, 150),
	Rare = Color3.fromRGB(100, 200, 255),
	Epic = Color3.fromRGB(180, 120, 255),
	Legendary = Color3.fromRGB(255, 220, 100),
}

-- Categories that are recognized filters; unknown categories map to "Misc".
local KNOWN_FILTER_CATEGORIES: { [string]: boolean } = {
	Material = true,
	Weapon = true,
	Armor = true,
	Accessory = true,
	Consumable = true,
	Cosmetic = true,
	Building = true,
}

--[=[
	@class ShopSlotViewModel
	Builders for shop grid cells in buy and sell tabs. Transforms raw item config and inventory data into display-ready view models.
]=]
local ShopSlotViewModel = {}

--[=[
	Resolve a raw item category string to a known filter category. Unknown or nil categories map to "Misc".
	@within ShopSlotViewModel
	@param itemCategory string? -- Raw category from item data
	@return string -- Resolved category filter
]=]
function ShopSlotViewModel.resolveCategoryFilter(itemCategory: string?): string
	if itemCategory == nil or itemCategory == "" then
		return "Misc"
	end
	if KNOWN_FILTER_CATEGORIES[itemCategory] then
		return itemCategory
	end
	return "Misc"
end

--[=[
	Build grid cells for the Buy tab from the shop catalog.
	@within ShopSlotViewModel
	@param currentGold number -- Player's current gold (used for affordability check)
	@param unlockState TUnlockState? -- Player's unlock state, or nil
	@return { TShopSlotViewModel } -- Grid cells sorted by category then price
]=]
function ShopSlotViewModel.buildBuyGrid(currentGold: number, unlockState: TUnlockState?): { TShopSlotViewModel }
	local catalog = ShopItemViewModel.buildCatalog(currentGold, unlockState)
	local grid: { TShopSlotViewModel } = {}

	for i, item in ipairs(catalog) do
		local isStackable = item.MaxStack > 1
		table.insert(grid, table.freeze({
			SlotIndex = i,
			ItemId = item.ItemId,
			ItemName = item.Name,
			ItemDescription = item.Description,
			ItemIcon = if item.Icon ~= "rbxassetid://0" then item.Icon else nil,
			Category = item.Category,
			Rarity = item.Rarity,
			RarityColor = RARITY_COLORS[item.Rarity],
			DisplayPrice = "$" .. tostring(item.BuyPrice),
			BuyPrice = item.BuyPrice,
			SellPrice = item.SellPrice or 0,
			Quantity = 0,
			MaxStack = item.MaxStack,
			IsStackable = isStackable,
			IsEmpty = false,
			NameAbbreviation = _nameAbbr(item.Name),
			StackableLabel = if isStackable then "Stackable (max " .. tostring(item.MaxStack) .. ")" else nil,
		} :: TShopSlotViewModel))
	end

	return grid
end

--[=[
	Build grid cells for the Sell tab from the player's inventory.
	@within ShopSlotViewModel
	@param inventoryState table -- Player's inventory state from InventoryController
	@return { TShopSlotViewModel } -- Grid cells of sellable items sorted by name
]=]
function ShopSlotViewModel.buildSellGrid(inventoryState: any): { TShopSlotViewModel }
	local sellList = SellItemViewModel.fromInventory(inventoryState)
	local grid: { TShopSlotViewModel } = {}

	for _, item in ipairs(sellList) do
		local itemData = ItemConfig[item.ItemId]
		local isStackable = if itemData then itemData.stackable else false
		local maxStack = if itemData then itemData.maxStack else 1
		table.insert(grid, table.freeze({
			SlotIndex = item.SlotIndex,
			ItemId = item.ItemId,
			ItemName = item.Name,
			ItemDescription = if itemData then itemData.description else "",
			ItemIcon = if item.Icon ~= "rbxassetid://0" then item.Icon else nil,
			Category = item.Category,
			Rarity = item.Rarity,
			RarityColor = RARITY_COLORS[item.Rarity],
			DisplayPrice = "$" .. tostring(item.SellPrice),
			BuyPrice = if itemData and itemData.BuyPrice then itemData.BuyPrice else 0,
			SellPrice = item.SellPrice,
			Quantity = item.Quantity,
			MaxStack = maxStack,
			IsStackable = isStackable,
			IsEmpty = false,
			NameAbbreviation = _nameAbbr(item.Name),
			StackableLabel = if isStackable then "Stackable (max " .. tostring(maxStack) .. ")" else nil,
		} :: TShopSlotViewModel))
	end

	return grid
end

return ShopSlotViewModel
