--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local InventoryState = require(ReplicatedStorage.Contexts.Inventory.Types.InventoryState)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

--[=[
	@class InventorySlotViewModel
	Transforms raw inventory slots into UI-ready view models with item metadata.
	@client
]=]

--[=[
	@interface TInventorySlotViewModel
	@within InventorySlotViewModel
	.SlotIndex number -- 1-based slot index
	.IsEmpty boolean -- True if slot has no item
	.ItemId string? -- Item identifier from ItemConfig
	.ItemName string? -- Display name
	.ItemDescription string? -- Flavor text
	.ItemIcon string? -- Asset path to icon
	.Quantity number? -- Stack size
	.Category string? -- Item category
	.Rarity string? -- Rarity tier (Common, Uncommon, Rare, Epic, Legendary)
	.RarityColor Color3? -- Color for rarity text
	.Stats { HP: number?, STR: number?, DEF: number?, SPD: number?, LCK: number? }? -- Item stats
	.IsStackable boolean? -- Whether item supports stacking
	.MaxStack number? -- Maximum stack size
	.NameAbbr string -- 2-letter uppercase abbreviation of item name, or "?"
]=]
export type TInventorySlotViewModel = {
	SlotIndex: number,
	IsEmpty: boolean,
	ItemId: string?,
	ItemName: string?,
	ItemDescription: string?,
	ItemIcon: string?,
	Quantity: number?,
	Category: string?,
	Rarity: string?,
	RarityColor: Color3?,
	Stats: { HP: number?, STR: number?, DEF: number?, SPD: number?, LCK: number? }?,
	IsStackable: boolean?,
	MaxStack: number?,
	NameAbbr: string,
}

local InventorySlotViewModel = {}

--[=[
	Transform a raw inventory slot into a view model.
	@within InventorySlotViewModel
	@param slot InventoryState.TInventorySlot -- Slot data from server
	@return TInventorySlotViewModel -- Enriched with item config metadata
]=]
function InventorySlotViewModel.fromSlot(slot: InventoryState.TInventorySlot): TInventorySlotViewModel
	local itemData = ItemConfig[slot.ItemId]

	-- Return empty slot view model if item not found or marked as "None"
	if not itemData or slot.ItemId == "None" then
		return table.freeze({
			SlotIndex = slot.SlotIndex,
			IsEmpty = true,
			ItemId = nil,
			ItemName = nil,
			ItemDescription = nil,
			ItemIcon = nil,
			Quantity = nil,
			Category = nil,
			Rarity = nil,
			RarityColor = nil,
			Stats = nil,
			IsStackable = nil,
			MaxStack = nil,
			NameAbbr = "?",
		} :: TInventorySlotViewModel)
	end

	-- Return filled slot with full item metadata
	return table.freeze({
		SlotIndex = slot.SlotIndex,
		IsEmpty = false,
		ItemId = slot.ItemId,
		ItemName = itemData.name,
		ItemDescription = itemData.description,
		ItemIcon = itemData.icon,
		Quantity = slot.Quantity,
		Category = slot.Category,
		Rarity = itemData.rarity,
		RarityColor = ColorTokens.Rarity[itemData.rarity],
		Stats = itemData.stats,
		IsStackable = itemData.stackable,
		MaxStack = itemData.maxStack,
		NameAbbr = string.sub(itemData.name, 1, 2):upper(),
	} :: TInventorySlotViewModel)
end

--[=[
	Create an empty slot view model at the specified index.
	@within InventorySlotViewModel
	@param slotIndex number -- 1-based slot index
	@return TInventorySlotViewModel -- Empty slot view model
]=]
function InventorySlotViewModel.emptySlot(slotIndex: number): TInventorySlotViewModel
	return table.freeze({
		SlotIndex = slotIndex,
		IsEmpty = true,
		ItemId = nil,
		ItemName = nil,
		ItemDescription = nil,
		ItemIcon = nil,
		Quantity = nil,
		Category = nil,
		Rarity = nil,
		RarityColor = nil,
		Stats = nil,
		IsStackable = nil,
		MaxStack = nil,
		NameAbbr = "?",
	} :: TInventorySlotViewModel)
end

--[=[
	Build a grid of view models for UI rendering.
	@within InventorySlotViewModel
	@param inventoryState InventoryState? -- Inventory state or nil
	@param filterCategory string? -- Category name to filter ("All" or nil shows all slots)
	@return { TInventorySlotViewModel } -- View models for grid display
]=]
function InventorySlotViewModel.buildGrid(
	inventoryState: InventoryState.TInventoryState?,
	filterCategory: string?
): { TInventorySlotViewModel }
	if not inventoryState then
		return {}
	end

	local slots = inventoryState.Slots
	local totalSlots = inventoryState.Metadata.TotalSlots
	local result: { TInventorySlotViewModel } = {}

	if not filterCategory or filterCategory == "All" then
		-- Fixed grid: show all slots (occupied or empty) to preserve layout
		for i = 1, totalSlots do
			local slot = slots[i]
			if slot then
				table.insert(result, InventorySlotViewModel.fromSlot(slot))
			else
				table.insert(result, InventorySlotViewModel.emptySlot(i))
			end
		end
	else
		-- Filtered view: only occupied slots matching this category, sorted by index
		local filtered: { TInventorySlotViewModel } = {}
		for _, slot in pairs(slots) do
			if slot and slot.Category == filterCategory then
				table.insert(filtered, InventorySlotViewModel.fromSlot(slot))
			end
		end
		table.sort(filtered, function(a, b)
			return (a.SlotIndex or 0) < (b.SlotIndex or 0)
		end)
		result = filtered
	end

	return result
end

--[=[
	Get the count of items matching a category filter.
	@within InventorySlotViewModel
	@param inventoryState InventoryState? -- Inventory state or nil
	@param filterCategory string? -- Category name ("All" or nil counts all items)
	@return number -- Item count
]=]
function InventorySlotViewModel.getFilteredCount(
	inventoryState: InventoryState.TInventoryState?,
	filterCategory: string?
): number
	if not inventoryState then
		return 0
	end

	if not filterCategory or filterCategory == "All" then
		return inventoryState.Metadata.UsedSlots
	end

	-- Count items in specific category
	local count = 0
	for _, slot in pairs(inventoryState.Slots) do
		if slot and slot.Category == filterCategory then
			count += 1
		end
	end
	return count
end

return InventorySlotViewModel
