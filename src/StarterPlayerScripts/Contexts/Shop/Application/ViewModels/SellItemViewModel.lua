--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)

--[=[
	@interface TSellItemViewModel
	View model for a single sellable inventory item.
	.SlotIndex number -- Inventory slot index
	.ItemId string -- Unique item identifier
	.Name string -- Display name
	.Icon string -- AssetId for the item icon
	.Category string -- Item category
	.Rarity string -- Rarity tier
	.Quantity number -- Current stack quantity
	.SellPrice number -- Sell value per unit in gold
	.TotalValue number -- Sell price × quantity
]=]
export type TSellItemViewModel = {
	SlotIndex: number,
	ItemId: string,
	Name: string,
	Icon: string,
	Category: string,
	Rarity: string,
	Quantity: number,
	SellPrice: number,
	TotalValue: number,
}

--[=[
	@class SellItemViewModel
	Builds a list of sellable inventory items from the player's current inventory state.
]=]
local SellItemViewModel = {}

--[=[
	Build a sell list from the player's inventory state. Only includes items with a SellPrice. Sorted alphabetically by name.
	@within SellItemViewModel
	@param inventoryState table -- Player's inventory state (expects .Slots table)
	@return { TSellItemViewModel } -- List of sellable items
]=]
function SellItemViewModel.fromInventory(inventoryState: any): { TSellItemViewModel }
	local sellList: { TSellItemViewModel } = {}

	if not inventoryState or not inventoryState.Slots then
		return sellList
	end

	for slotIndex, slot in pairs(inventoryState.Slots) do
		if slot and slot.ItemId then
			local itemData = ItemConfig[slot.ItemId]
			if itemData and itemData.SellPrice and itemData.SellPrice > 0 then
				table.insert(sellList, table.freeze({
					SlotIndex = slotIndex,
					ItemId = slot.ItemId,
					Name = itemData.name,
					Icon = itemData.icon,
					Category = itemData.category,
					Rarity = itemData.rarity,
					Quantity = slot.Quantity,
					SellPrice = itemData.SellPrice,
					TotalValue = itemData.SellPrice * slot.Quantity,
				}) :: TSellItemViewModel)
			end
		end
	end

	-- Sort by name
	table.sort(sellList, function(a, b)
		return a.Name < b.Name
	end)

	return sellList
end

return SellItemViewModel
