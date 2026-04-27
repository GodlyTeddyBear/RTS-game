--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local InventoryState = require(ReplicatedStorage.Contexts.Inventory.Types.InventoryState)

type ResourceWallet = EconomyTypes.ResourceWallet
type TInventoryState = InventoryState.TInventoryState
type TInventorySlot = InventoryState.TInventorySlot

export type TInventoryResourceRow = {
	Name: string,
	AmountText: string,
	IsSyncing: boolean,
	LayoutOrder: number,
}

export type TInventorySlotRow = {
	SlotIndex: number,
	Name: string,
	QuantityText: string,
	Rarity: string,
	Category: string,
	LayoutOrder: number,
}

export type TInventoryViewData = {
	Title: string,
	CapacityText: string,
	IsResourceSyncing: boolean,
	IsInventoryEmpty: boolean,
	ResourceRows: { TInventoryResourceRow },
	SlotRows: { TInventorySlotRow },
	OverflowText: string?,
}

local MAX_VISIBLE_SLOTS = 15

local InventoryViewModel = {}

local function _FormatAmount(amount: number): string
	return tostring(math.floor(amount))
end

local function _CreateResourceRow(name: string, amount: number, isSyncing: boolean, layoutOrder: number): TInventoryResourceRow
	return table.freeze({
		Name = name,
		AmountText = if isSyncing then "Syncing..." else _FormatAmount(amount),
		IsSyncing = isSyncing,
		LayoutOrder = layoutOrder,
	} :: TInventoryResourceRow)
end

local function _BuildResourceRows(wallet: ResourceWallet?): ({ TInventoryResourceRow }, boolean)
	if wallet == nil then
		return {
			_CreateResourceRow("Energy", 0, true, 1),
		}, true
	end

	local rows = {
		_CreateResourceRow("Energy", wallet.energy, false, 1),
	}

	local resourceNames = {}
	for resourceName in wallet.resources do
		table.insert(resourceNames, resourceName)
	end
	table.sort(resourceNames)

	for index, resourceName in resourceNames do
		table.insert(rows, _CreateResourceRow(resourceName, wallet.resources[resourceName] or 0, false, index + 1))
	end

	return rows, false
end

local function _CreateSlotRow(slot: TInventorySlot): TInventorySlotRow
	local itemData = ItemConfig[slot.ItemId]
	local itemName = if itemData then itemData.name else slot.ItemId
	local rarity = if itemData then itemData.rarity else "Common"
	local category = if itemData then itemData.category else slot.Category

	return table.freeze({
		SlotIndex = slot.SlotIndex,
		Name = itemName,
		QuantityText = ("x%d"):format(slot.Quantity),
		Rarity = rarity,
		Category = category,
		LayoutOrder = slot.SlotIndex,
	} :: TInventorySlotRow)
end

local function _BuildSlotRows(inventoryState: TInventoryState): ({ TInventorySlotRow }, string?)
	local slots = {}
	for _, slot in inventoryState.Slots do
		table.insert(slots, slot)
	end

	table.sort(slots, function(a: TInventorySlot, b: TInventorySlot): boolean
		return a.SlotIndex < b.SlotIndex
	end)

	local rows = {}
	for index, slot in slots do
		if index > MAX_VISIBLE_SLOTS then
			break
		end

		table.insert(rows, _CreateSlotRow(slot))
	end

	local overflowCount = #slots - #rows
	local overflowText = if overflowCount > 0 then ("+%d more"):format(overflowCount) else nil
	return rows, overflowText
end

function InventoryViewModel.fromState(inventoryState: TInventoryState, wallet: ResourceWallet?): TInventoryViewData
	local resourceRows, isResourceSyncing = _BuildResourceRows(wallet)
	local slotRows, overflowText = _BuildSlotRows(inventoryState)
	local metadata = inventoryState.Metadata

	return table.freeze({
		Title = "Inventory",
		CapacityText = ("%d / %d slots"):format(metadata.UsedSlots, metadata.TotalSlots),
		IsResourceSyncing = isResourceSyncing,
		IsInventoryEmpty = #slotRows == 0,
		ResourceRows = resourceRows,
		SlotRows = slotRows,
		OverflowText = overflowText,
	} :: TInventoryViewData)
end

return table.freeze(InventoryViewModel)
