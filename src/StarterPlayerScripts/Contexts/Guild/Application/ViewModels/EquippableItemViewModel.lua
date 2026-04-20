--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)

export type TEquippableItemViewData = {
	SlotIndex: number,
	ItemId: string,
	Name: string,
	StatsText: string,
	Quantity: number,
}

-- Maps slot type to required item category
local SLOT_TO_CATEGORY: { [string]: string } = {
	Weapon = "Weapon",
	Armor = "Armor",
	Accessory = "Accessory",
}

local EquippableItemViewModel = {}

local function _BuildStatsText(stats: { [string]: number }?): string
	-- Guard: no stats = empty string
	if not stats then
		return ""
	end
	-- Build comma-separated stat bonuses (e.g. "+5 STR, +3 DEF")
	local parts = {}
	for stat, value in pairs(stats) do
		table.insert(parts, "+" .. tostring(value) .. " " .. stat)
	end
	return table.concat(parts, ", ")
end

function EquippableItemViewModel.buildList(inventoryState: any, slotType: string): { TEquippableItemViewData }
	-- Map slot type to required item category (Weapon, Armor, Accessory)
	local requiredCategory = SLOT_TO_CATEGORY[slotType]
	local result: { TEquippableItemViewData } = {}

	-- Guard: empty inventory
	if not inventoryState or not inventoryState.Slots then
		return result
	end

	-- Filter inventory to items matching the slot category
	for slotIndex, slot in pairs(inventoryState.Slots) do
		if slot and slot.ItemId then
			local itemData = ItemConfig[slot.ItemId]
			if itemData and itemData.category == requiredCategory then
				table.insert(result, table.freeze({
					SlotIndex = slotIndex,
					ItemId = slot.ItemId,
					Name = itemData.name,
					StatsText = _BuildStatsText(itemData.stats),
					Quantity = slot.Quantity,
				} :: TEquippableItemViewData))
			end
		end
	end

	-- Sort alphabetically for predictable UI
	table.sort(result, function(a, b)
		return a.Name < b.Name
	end)

	return result
end

return EquippableItemViewModel
