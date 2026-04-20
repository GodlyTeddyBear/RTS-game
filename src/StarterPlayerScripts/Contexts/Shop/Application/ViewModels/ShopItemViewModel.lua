--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local UnlockConfig = require(ReplicatedStorage.Contexts.Unlock.Config.UnlockConfig)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState

--[=[
	@interface TShopItemViewModel
	View model for a single item in the shop catalog.
	.ItemId string -- Unique item identifier
	.Name string -- Display name
	.Description string -- Item description
	.Icon string -- AssetId for the item icon
	.Category string -- Item category
	.Rarity string -- Rarity tier
	.BuyPrice number -- Cost in gold
	.SellPrice number? -- Sell value, or nil if unsellable
	.MaxStack number -- Maximum stack size
	.CanAfford boolean -- Whether player has enough gold to buy
]=]
export type TShopItemViewModel = {
	ItemId: string,
	Name: string,
	Description: string,
	Icon: string,
	Category: string,
	Rarity: string,
	BuyPrice: number,
	SellPrice: number?,
	MaxStack: number,
	CanAfford: boolean,
}

--[=[
	@class ShopItemViewModel
	Builds the buyable shop catalog by filtering and sorting items from global ItemConfig based on unlock state and affordability.
]=]
local ShopItemViewModel = {}

-- Check whether an item is available for purchase based on unlock state. Items in UnlockConfig with StartsUnlocked=true do not require an unlock entry.
local function _isItemUnlocked(itemId: string, unlockState: TUnlockState): boolean
	local entry = UnlockConfig[itemId]
	-- Shop strict mode: explicit unlock key coverage is required.
	if not entry then
		return false
	end
	if entry.StartsUnlocked then
		return true
	end
	return unlockState[itemId] == true
end

--[=[
	Build the complete buy catalog: all items from ItemConfig that have a BuyPrice and are unlocked. Sorted by category then price.
	@within ShopItemViewModel
	@param currentGold number -- Player's gold (used for CanAfford flag)
	@param unlockState TUnlockState? -- Player's unlock state, or nil to use empty state
	@return { TShopItemViewModel } -- Catalog of purchasable items
]=]
function ShopItemViewModel.buildCatalog(currentGold: number, unlockState: TUnlockState?): { TShopItemViewModel }
	local catalog: { TShopItemViewModel } = {}
	local resolvedUnlockState = unlockState or {}

	for itemId, itemData in pairs(ItemConfig) do
		if itemData.BuyPrice and itemData.BuyPrice > 0 and _isItemUnlocked(itemId, resolvedUnlockState) then
			table.insert(catalog, table.freeze({
				ItemId = itemId,
				Name = itemData.name,
				Description = itemData.description,
				Icon = itemData.icon,
				Category = itemData.category,
				Rarity = itemData.rarity,
				BuyPrice = itemData.BuyPrice,
				SellPrice = itemData.SellPrice,
				MaxStack = itemData.maxStack,
				CanAfford = currentGold >= itemData.BuyPrice,
			}) :: TShopItemViewModel)
		end
	end

	-- Sort by category, then by price within category
	table.sort(catalog, function(a, b)
		if a.Category ~= b.Category then
			return a.Category < b.Category
		end
		return a.BuyPrice < b.BuyPrice
	end)

	return catalog
end

return ShopItemViewModel
