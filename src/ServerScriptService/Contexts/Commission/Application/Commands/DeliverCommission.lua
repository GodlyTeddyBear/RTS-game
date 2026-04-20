--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok, Err, Try, Ensure = Result.Ok, Result.Err, Result.Try, Result.Ensure
local MentionSuccess = Result.MentionSuccess

--[[
	DeliverCommission

	Delivers items for an active commission: removes items from inventory,
	grants gold + token rewards, removes commission from active list.
	Follows the slot-drain pattern from CraftItem.lua.
]]

--[=[
	@class DeliverCommission
	Application command that delivers items for an active commission, drains inventory, grants rewards, and removes the commission.
	@server
]=]
local DeliverCommission = {}
DeliverCommission.__index = DeliverCommission

--[=[
	Construct a new DeliverCommission service.
	@within DeliverCommission
	@return DeliverCommission
]=]
function DeliverCommission.new()
	return setmetatable({}, DeliverCommission)
end

--[=[
	Wire intra-context registry dependencies (called by Registry:InitAll).
	@within DeliverCommission
	@param registry any -- The context registry
]=]
function DeliverCommission:Init(registry: any, _name: string)
	self.DeliverPolicy = registry:Get("DeliverPolicy")
	self.CommissionSyncService = registry:Get("CommissionSyncService")
	self.CommissionPersistenceService = registry:Get("CommissionPersistenceService")
end

--[=[
	Wire cross-context dependencies (`InventoryContext`, `ShopContext`) after KnitStart.
	@within DeliverCommission
]=]
function DeliverCommission:Start()
	local Knit = require(ReplicatedStorage.Packages.Knit)
	self.InventoryContext = Knit.GetService("InventoryContext")
	self.ShopContext = Knit.GetService("ShopContext")
end

--[=[
	Deliver an active commission: drain required items, grant rewards, and persist state.
	@within DeliverCommission
	@param player Player -- The player delivering the commission
	@param userId number -- The player's UserId
	@param commissionId string -- The ID of the active commission to deliver
	@return Result<boolean> -- `Ok(true)` on success
]=]
function DeliverCommission:Execute(player: Player, userId: number, commissionId: string): Result.Result<boolean>
	Ensure(player ~= nil and userId > 0, "InvalidInput", "Invalid player or userId")

	-- Validate commission and fetch state
	local ctx = Try(self.DeliverPolicy:Check(userId, commissionId))
	local commission     = ctx.Commission
	local inventoryState = ctx.InventoryState

	-- Remove required items from inventory
	Try(self:_DrainRequiredItems(userId, commission.Requirement, inventoryState))

	-- Grant gold, tokens, and bonus items
	self:_GrantRewards(player, userId, commission.Reward)

	-- Remove from active list and persist
	self:_FinalizeCommission(player, userId, commissionId)

	MentionSuccess("Commission:DeliverCommission:Execute", "Delivered commission and granted configured rewards", {
		userId = userId,
		commissionId = commissionId,
	})

	return Ok(true)
end

function DeliverCommission:_DrainRequiredItems(userId: number, requirement: any, inventoryState: any): Result.Result<boolean>
	local requiredItemId = requirement.ItemId

	-- Collect all slots containing the required item
	local matchingSlots = self:_CollectMatchingSlots(inventoryState, requiredItemId)

	-- Remove items from slots in order, tracking remainder if insufficient stock
	local remaining = self:_RemoveFromSlots(userId, matchingSlots, requirement.Quantity)

	-- Fail if we couldn't remove enough items
	if remaining > 0 then
		return Err("DeliverFailed", Errors.DELIVER_FAILED, { itemId = requiredItemId, remaining = remaining })
	end

	return Ok(true)
end

function DeliverCommission:_CollectMatchingSlots(inventoryState: any, itemId: string): { { SlotIndex: number, Quantity: number } }
	local matchingSlots: { { SlotIndex: number, Quantity: number } } = {}

	-- Scan all slots and collect indices of those matching the required item
	for slotIndex, slot in pairs(inventoryState.Slots) do
		if slot and slot.ItemId == itemId then
			table.insert(matchingSlots, { SlotIndex = slotIndex, Quantity = slot.Quantity })
		end
	end

	-- Sort by quantity ascending; drain smaller stacks first to minimize fragmentation
	table.sort(matchingSlots, function(a, b)
		return a.Quantity < b.Quantity
	end)

	return matchingSlots
end

function DeliverCommission:_RemoveFromSlots(userId: number, matchingSlots: { { SlotIndex: number, Quantity: number } }, quantity: number): number
	local remaining = quantity

	-- Drain items from each slot in order until requirement met or stock exhausted
	for _, slotInfo in ipairs(matchingSlots) do
		if remaining <= 0 then
			break
		end

		-- Remove min(remaining, slot quantity) from this slot
		local toRemove = math.min(remaining, slotInfo.Quantity)
		Try(self.InventoryContext:RemoveItemFromInventory(userId, slotInfo.SlotIndex, toRemove))
		remaining = remaining - toRemove
	end

	return remaining
end

function DeliverCommission:_GrantRewards(player: Player, userId: number, reward: any)
	-- Grant gold reward via ShopContext
	Try(self.ShopContext:AddGold(player, userId, reward.Gold))

	-- Grant commission tokens (tracked separately from gold)
	self:_GrantTokens(userId, reward.Tokens)

	-- Grant bonus items if configured
	if reward.Items then
		for _, rewardItem in ipairs(reward.Items) do
			Try(self.InventoryContext:AddItemToInventory(userId, rewardItem.ItemId, rewardItem.Quantity))
		end
	end
end

function DeliverCommission:_GrantTokens(userId: number, amount: number)
	local currentState: any = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if currentState then
		self.CommissionSyncService:SetTokens(userId, currentState.Tokens + amount)
	end
end

function DeliverCommission:_FinalizeCommission(player: Player, userId: number, commissionId: string)
	-- Remove commission from active list
	self.CommissionSyncService:RemoveFromActive(userId, commissionId)

	-- Persist updated state to profile
	local updatedState = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	if updatedState then
		Try(self.CommissionPersistenceService:SaveCommissionData(player, updatedState))
	end

	-- Sync state to client
	self.CommissionSyncService:HydratePlayer(player)
end

return DeliverCommission
