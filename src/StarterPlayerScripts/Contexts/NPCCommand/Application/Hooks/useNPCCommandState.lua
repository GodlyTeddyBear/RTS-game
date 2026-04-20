--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])

local NPCEntryViewModel = require(script.Parent.Parent.ViewModels.NPCEntryViewModel)
local ConsumableEntryViewModel = require(script.Parent.Parent.ViewModels.ConsumableEntryViewModel)
local NPCCommandTypes = require(script.Parent.Parent.Parent.Types.NPCCommandTypes)

local useAtom = ReactCharm.useAtom

local questStateAtom = nil
local inventoryStateAtom = nil

export type TNPCCommandUIState = {
	rosterNPCs: { NPCCommandTypes.TNPCEntry },
	consumables: { NPCCommandTypes.TConsumableEntry },
	selectedNpcIds: { string },
	selectedCount: number,
	recentOrders: { NPCCommandTypes.TOrderEntry },
	isPickingTarget: boolean,
	isInExpedition: boolean,
}

--[[
	Read hook that subscribes to NPCCommandController's roster, selection, and order atoms.

	Re-renders whenever the roster or selection changes, or an order is issued.
	Returns the full UI state needed by NPCCommandScreen.
]]
local function useNPCCommandState(): TNPCCommandUIState
	local controller = Knit.GetController("NPCCommandController")
	if not controller then
		return {
			rosterNPCs = {},
			consumables = {},
			selectedNpcIds = {},
			selectedCount = 0,
			recentOrders = {},
			isPickingTarget = false,
			isInExpedition = false,
		}
	end

	-- Lazy-resolve quest state atom once
	if questStateAtom == nil then
		local questController = Knit.GetController("QuestController")
		if questController then
			questStateAtom = questController:GetQuestStateAtom()
		end
	end
	local questState = if questStateAtom then useAtom(questStateAtom) else nil
	local isInExpedition = questState ~= nil and questState.ActiveExpedition ~= nil

	if inventoryStateAtom == nil then
		local inventoryController = Knit.GetController("InventoryController")
		if inventoryController then
			inventoryStateAtom = inventoryController:GetInventoriesAtom()
		end
	end
	local inventoryState = if inventoryStateAtom then useAtom(inventoryStateAtom) else nil

	-- Subscribe to atoms — re-renders when any changes
	local rosterModels = useAtom(controller:GetRosterAtom()) :: { [string]: Model }
	local selectionIds = useAtom(controller:GetSelectionAtom()) :: { [string]: boolean }
	local rawOrders = useAtom(controller:GetRecentOrdersAtom()) :: { any }
	local isPickingTarget = useAtom(controller:GetPickTargetAtom()) :: boolean

	-- Build full roster with selection state embedded
	local rosterNPCs = NPCEntryViewModel.buildList(rosterModels, selectionIds)

	-- Count selected
	local selectedCount = 0
	for _, _ in selectionIds do
		selectedCount += 1
	end
	local selectedNpcIds: { string } = {}
	for npcId, _ in selectionIds do
		table.insert(selectedNpcIds, npcId)
	end
	table.sort(selectedNpcIds)

	-- Build order view models
	local recentOrders: { NPCCommandTypes.TOrderEntry } = {}
	for i, order in rawOrders do
		table.insert(recentOrders, {
			NPCType = order.NPCType,
			CommandType = order.CommandType,
			TimestampLabel = NPCEntryViewModel.formatTimestamp(order.IssuedAt),
			LayoutOrder = i,
		})
	end

	return {
		rosterNPCs = rosterNPCs,
		consumables = ConsumableEntryViewModel.buildList(inventoryState),
		selectedNpcIds = selectedNpcIds,
		selectedCount = selectedCount,
		recentOrders = recentOrders,
		isPickingTarget = isPickingTarget,
		isInExpedition = isInExpedition,
	}
end

return useNPCCommandState
