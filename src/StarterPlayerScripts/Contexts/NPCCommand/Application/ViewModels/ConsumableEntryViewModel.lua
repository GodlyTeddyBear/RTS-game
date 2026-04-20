--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local InventoryState = require(ReplicatedStorage.Contexts.Inventory.Types.InventoryState)
local NPCCommandTypes = require(script.Parent.Parent.Parent.Types.NPCCommandTypes)

local ConsumableEntryViewModel = {}

function ConsumableEntryViewModel.buildList(inventoryState: InventoryState.TInventoryState?): { NPCCommandTypes.TConsumableEntry }
	if not inventoryState then
		return {}
	end

	local entries: { NPCCommandTypes.TConsumableEntry } = {}
	for _, slot in pairs(inventoryState.Slots) do
		if slot and slot.Category == "Consumable" then
			local itemData = ItemConfig[slot.ItemId]
			if itemData then
				local healAmount = itemData.stats and itemData.stats.HP or nil
				table.insert(entries, {
					SlotIndex = slot.SlotIndex,
					ItemId = slot.ItemId,
					ItemName = itemData.name,
					Quantity = slot.Quantity,
					HealAmount = healAmount,
					IsHealing = healAmount ~= nil and healAmount > 0,
					NameAbbr = string.sub(itemData.name, 1, 2):upper(),
					LayoutOrder = slot.SlotIndex,
				})
			end
		end
	end

	table.sort(entries, function(a, b)
		return a.SlotIndex < b.SlotIndex
	end)

	return entries
end

return ConsumableEntryViewModel
