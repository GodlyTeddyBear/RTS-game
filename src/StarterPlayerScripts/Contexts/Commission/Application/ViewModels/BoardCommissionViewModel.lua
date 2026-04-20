--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local CommissionRewardConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionRewardConfig)

--[=[
	@class BoardCommissionViewModel
	Transforms board commission data into display-ready format. Checks slot capacity to determine if player can accept.
]=]

--[=[
	@interface TBoardCommissionVM
	@within BoardCommissionViewModel
	.Id string -- Commission ID
	.PoolId string -- Commission pool ID
	.ItemName string -- Display name of required item
	.ItemIcon string -- Asset ID of item icon
	.Quantity number -- Quantity required to complete
	.QuantityLabel string -- Formatted quantity (e.g., "x10 Gold Ore")
	.ProgressLabel string -- Initial progress label (always "0 / N Item")
	.GoldReward string -- Formatted gold reward
	.TokenReward string -- Formatted token reward
	.TierLabel string -- Tier display
	.ExpiresAt number -- Unix timestamp of expiration
	.CanAccept boolean -- Whether player has slots available (activeCount < MAX_ACTIVE)
]=]

export type TBoardCommissionVM = {
	Id: string,
	PoolId: string,
	ItemName: string,
	ItemIcon: string,
	Quantity: number,
	QuantityLabel: string,
	ProgressLabel: string,
	GoldReward: string,
	TokenReward: string,
	TierLabel: string,
	ExpiresAt: number,
	CanAccept: boolean,
}

local BoardCommissionViewModel = {}

--[=[
	Transform a single board commission into display-ready view model.
	@within BoardCommissionViewModel
	@param commission any -- Raw TBoardCommission from server
	@param activeCount number -- Current number of active commissions player has
	@return TBoardCommissionVM -- Display-ready view model
]=]
function BoardCommissionViewModel.fromBoardCommission(commission: any, activeCount: number): TBoardCommissionVM
	local itemDef = ItemConfig[commission.Requirement.ItemId]
	local itemName = itemDef and itemDef.name or commission.Requirement.ItemId
	local itemIcon = itemDef and itemDef.icon or "rbxassetid://0"

	local qty = commission.Requirement.Quantity
	-- Check if player can accept: must have slot available (activeCount < MAX_ACTIVE)
	local canAccept = activeCount < CommissionRewardConfig.MAX_ACTIVE
	return table.freeze({
		Id = commission.Id,
		PoolId = commission.PoolId,
		ItemName = itemName,
		ItemIcon = itemIcon,
		Quantity = qty,
		QuantityLabel = "x" .. qty .. " " .. itemName,
		ProgressLabel = "0 / " .. qty .. " " .. itemName,
		GoldReward = tostring(commission.Reward.Gold) .. " Gold",
		TokenReward = tostring(commission.Reward.Tokens) .. " Tokens",
		TierLabel = "Tier " .. commission.Tier,
		ExpiresAt = commission.ExpiresAt,
		CanAccept = canAccept,
	})
end

--[=[
	Transform a list of board commissions into view models.
	@within BoardCommissionViewModel
	@param board { any } -- List of raw TBoardCommission objects
	@param activeCount number -- Current number of active commissions
	@return { TBoardCommissionVM } -- List of display-ready view models
]=]
function BoardCommissionViewModel.fromBoardList(board: { any }, activeCount: number): { TBoardCommissionVM }
	local result = {}
	for _, commission in ipairs(board) do
		table.insert(result, BoardCommissionViewModel.fromBoardCommission(commission, activeCount))
	end
	return result
end

return BoardCommissionViewModel
