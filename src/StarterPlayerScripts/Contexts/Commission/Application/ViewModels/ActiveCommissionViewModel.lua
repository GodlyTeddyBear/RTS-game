--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)

--[=[
	@class ActiveCommissionViewModel
	Transforms active commission data into display-ready format. Calculates progress by counting items in player inventory.
]=]

--[=[
	@interface TActiveCommissionVM
	@within ActiveCommissionViewModel
	.Id string -- Commission ID
	.PoolId string -- Commission pool ID
	.ItemName string -- Display name of required item
	.ItemIcon string -- Asset ID of item icon
	.RequiredQty number -- Quantity required to complete
	.CurrentQty number -- Quantity currently in inventory (clamped to required)
	.ProgressLabel string -- Formatted progress string (e.g., "5/10 Gold Ore")
	.IsComplete boolean -- Whether player has enough items to deliver
	.GoldReward string -- Formatted gold reward (e.g., "100 Gold")
	.TokenReward string -- Formatted token reward (e.g., "50 Tokens")
	.TierLabel string -- Tier display (e.g., "Tier 3")
]=]

export type TActiveCommissionVM = {
	Id: string,
	PoolId: string,
	ItemName: string,
	ItemIcon: string,
	RequiredQty: number,
	CurrentQty: number,
	ProgressLabel: string,
	IsComplete: boolean,
	GoldReward: string,
	TokenReward: string,
	TierLabel: string,
}

local ActiveCommissionViewModel = {}

-- Count how many of a specific item the player has in inventory.
-- Guards against nil inventory state or missing slots table.
local function _CountItemInInventory(inventoryState: any, itemId: string): number
	if not inventoryState or not inventoryState.Slots then
		return 0
	end

	local count = 0
	for _, slot in pairs(inventoryState.Slots) do
		if slot and slot.ItemId == itemId then
			count = count + slot.Quantity
		end
	end
	return count
end

--[=[
	Transform a single active commission into display-ready view model.
	@within ActiveCommissionViewModel
	@param commission any -- Raw TActiveCommission from server
	@param inventoryState any -- Player inventory state with Slots table
	@return TActiveCommissionVM -- Display-ready view model
]=]
function ActiveCommissionViewModel.fromActiveCommission(commission: any, inventoryState: any): TActiveCommissionVM
	local itemDef = ItemConfig[commission.Requirement.ItemId]
	local itemName = itemDef and itemDef.name or commission.Requirement.ItemId
	local itemIcon = itemDef and itemDef.icon or "rbxassetid://0"

	local requiredQty = commission.Requirement.Quantity
	-- Count actual inventory; clamp display to max required (shows "5/10" not "15/10" if player has excess)
	local currentQty = _CountItemInInventory(inventoryState, commission.Requirement.ItemId)
	local displayQty = math.min(currentQty, requiredQty)

	return table.freeze({
		Id = commission.Id,
		PoolId = commission.PoolId,
		ItemName = itemName,
		ItemIcon = itemIcon,
		RequiredQty = requiredQty,
		CurrentQty = displayQty,
		ProgressLabel = displayQty .. "/" .. requiredQty .. " " .. itemName,
		IsComplete = currentQty >= requiredQty,
		GoldReward = tostring(commission.Reward.Gold) .. " Gold",
		TokenReward = tostring(commission.Reward.Tokens) .. " Tokens",
		TierLabel = "Tier " .. commission.Tier,
	})
end

--[=[
	Transform a list of active commissions into view models.
	@within ActiveCommissionViewModel
	@param active { any } -- List of raw TActiveCommission objects
	@param inventoryState any -- Player inventory state
	@return { TActiveCommissionVM } -- List of display-ready view models
]=]
function ActiveCommissionViewModel.fromActiveList(active: { any }, inventoryState: any): { TActiveCommissionVM }
	local result = {}
	for _, commission in ipairs(active) do
		table.insert(result, ActiveCommissionViewModel.fromActiveCommission(commission, inventoryState))
	end
	return result
end

return ActiveCommissionViewModel
