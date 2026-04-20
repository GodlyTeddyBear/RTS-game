--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Contexts.Inventory.Config.ItemConfig)
local CommissionRewardConfig = require(ReplicatedStorage.Contexts.Commission.Config.CommissionRewardConfig)

export type TVillagerOfferVM = {
	OfferId: string,
	VillagerName: string,
	ItemName: string,
	ItemIcon: string,
	Quantity: number,
	QuantityLabel: string,
	GoldReward: string,
	TokenReward: string,
	TierLabel: string,
	CanAccept: boolean,
}

local VillagerOfferViewModel = {}

function VillagerOfferViewModel.fromOffer(offer: any, villagerName: string, activeCount: number): TVillagerOfferVM
	local requirement = offer.Requirement
	local reward = offer.Reward
	local itemDef = ItemConfig[requirement.ItemId]
	local itemName = itemDef and itemDef.name or requirement.ItemId
	local itemIcon = itemDef and itemDef.icon or "rbxassetid://0"
	local quantity = requirement.Quantity

	return table.freeze({
		OfferId = offer.Id,
		VillagerName = villagerName,
		ItemName = itemName,
		ItemIcon = itemIcon,
		Quantity = quantity,
		QuantityLabel = "x" .. tostring(quantity) .. " " .. itemName,
		GoldReward = tostring(reward.Gold) .. " Gold",
		TokenReward = tostring(reward.Tokens) .. " Tokens",
		TierLabel = "Tier " .. tostring(offer.Tier),
		CanAccept = activeCount < CommissionRewardConfig.MAX_ACTIVE,
	})
end

return VillagerOfferViewModel
