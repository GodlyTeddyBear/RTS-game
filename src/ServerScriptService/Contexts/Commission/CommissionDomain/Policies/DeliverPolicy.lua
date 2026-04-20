--!strict

--[[
	DeliverPolicy — Domain Policy

	Answers: can this player deliver the given active commission?

	RESPONSIBILITIES:
	  1. Fetch commission state from CommissionSyncService
	  2. Fetch inventory state from InventoryContext
	  3. Find the active commission and sum available item quantities
	  4. Build a TDeliverCommissionCandidate and evaluate CanDeliverCommission
	  5. Return Ok({ Commission, InventoryState }) so the command avoids re-reads

	RESULT:
	  Ok({ Commission, InventoryState }) — delivery is valid; data returned for command use
	  Err(...)                           — player/inventory not found, commission not active,
	                                       or insufficient items

	USAGE:
	  -- Inside a Catch boundary (Application command):
	  local ctx = Try(self.DeliverPolicy:Check(userId, commissionId))
	  local commission     = ctx.Commission
	  local inventoryState = ctx.InventoryState
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CommissionSpecs = require(script.Parent.Parent.Specs.CommissionSpecs)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class DeliverPolicy
	Domain policy that answers whether a player may deliver an active commission.
	@server
]=]
local DeliverPolicy = {}
DeliverPolicy.__index = DeliverPolicy

--[=[
	@type TDeliverPolicy typeof(setmetatable({}, DeliverPolicy))
	@within DeliverPolicy
]=]
export type TDeliverPolicy = typeof(setmetatable({}, DeliverPolicy))

--[=[
	Construct a new DeliverPolicy.
	@within DeliverPolicy
	@return TDeliverPolicy
]=]
function DeliverPolicy.new(): TDeliverPolicy
	return setmetatable({}, DeliverPolicy)
end

--[=[
	Wire intra-context registry dependencies (called by Registry:InitAll).
	@within DeliverPolicy
	@param registry any -- The context registry
]=]
function DeliverPolicy:Init(registry: any)
	self.CommissionSyncService = registry:Get("CommissionSyncService")
end

--[=[
	Wire cross-context dependencies after KnitStart.
	@within DeliverPolicy
]=]
function DeliverPolicy:Start()
	local Knit = require(ReplicatedStorage.Packages.Knit)
	self.InventoryContext = Knit.GetService("InventoryContext")
end

local function _FindActiveCommission(active: { any }, commissionId: string): any?
	for _, c in ipairs(active) do
		if c.Id == commissionId then
			return c
		end
	end
	return nil
end

local function _CountAvailableItems(inventoryState: any, commission: any?): number
	if not commission or not inventoryState.Slots then
		return 0
	end
	local requiredItemId = commission.Requirement.ItemId
	local total = 0
	for _, slot in pairs(inventoryState.Slots) do
		if slot and slot.ItemId == requiredItemId then
			total += slot.Quantity
		end
	end
	return total
end

--[=[
	Evaluate whether the player may deliver the given commission and return data needed by the command.
	@within DeliverPolicy
	@param userId number -- The player's UserId
	@param commissionId string -- The ID of the active commission to deliver
	@return Result<{Commission: any, InventoryState: any}> -- Validated commission and inventory state, or `Err`
]=]
function DeliverPolicy:Check(userId: number, commissionId: string): Result.Result<{ Commission: any, InventoryState: any }>
	-- Fetch player's commission state (fails if not loaded)
	local state = self.CommissionSyncService:GetCommissionStateReadOnly(userId)
	Ensure(state ~= nil, "PlayerNotFound", Errors.PLAYER_NOT_FOUND)

	-- Fetch player's inventory (fails if not accessible)
	local inventoryState = Try(self.InventoryContext:GetPlayerInventory(userId))
	Ensure(inventoryState ~= nil, "InventoryNotFound", Errors.INVENTORY_NOT_FOUND)

	-- Find commission in active list and count available items
	local commission = _FindActiveCommission(state.Active, commissionId)
	local availableQty = _CountAvailableItems(inventoryState, commission)

	-- Build candidate for spec evaluation
	local candidate: CommissionSpecs.TDeliverCommissionCandidate = {
		CommissionIdValid = commissionId ~= nil and commissionId ~= "",
		-- Defensive: passes when commissionId invalid — only the root error fires
		CommissionActive  = commissionId == nil or commissionId == "" or commission ~= nil,
		SufficientItems   = commissionId == nil or commissionId == "" or commission == nil
			or availableQty >= commission.Requirement.Quantity,
	}

	-- Evaluate all eligibility requirements
	Try(CommissionSpecs.CanDeliverCommission:IsSatisfiedBy(candidate))

	return Ok({ Commission = commission, InventoryState = inventoryState })
end

return DeliverPolicy
