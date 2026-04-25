--!strict

--[[
	Module: ResourceValidator
	Purpose: Validates economy resource earnings, spending, and cap handling.
	Used In System: Called by Economy application commands before wallet mutations occur.
	Boundaries: Owns validation rules only; does not own wallet mutation or persistence.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyConfig = require(ReplicatedStorage.Contexts.Economy.Config.EconomyConfig)
local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)

local Ok = Result.Ok
local Err = Result.Err

type ResourceCostMap = EconomyTypes.ResourceCostMap

--[=[
	@class ResourceValidator
	Validates economy resource earnings, spending, and cap handling.
	@server
]=]
local ResourceValidator = {}
ResourceValidator.__index = ResourceValidator

-- [Initialization]

-- Seeds the known resource lookup once so validation stays O(1) per call.
--[=[
	Creates a new resource validator.
	@within ResourceValidator
	@return ResourceValidator -- The new validator instance.
]=]
function ResourceValidator.new()
	local self = setmetatable({}, ResourceValidator)

	self._knownResources = {
		Energy = true,
	}

	for _, resourceType in EconomyConfig.RESOURCE_TYPES do
		self._knownResources[resourceType] = true
	end

	return self
end

-- [Private Helpers]

-- Rejects zero, negatives, and fractional values so all wallet math stays integral.
function ResourceValidator:_IsPositiveInteger(amount: number): boolean
	return amount > 0 and math.floor(amount) == amount
end

-- Treats Energy plus configured zone resources as the only valid wallet keys.
function ResourceValidator:_IsKnownResourceType(resourceType: string): boolean
	return self._knownResources[resourceType] == true
end

-- [Public API]

-- Validates a resource grant before the sync service mutates the wallet.
-- This keeps write commands from applying partial state on malformed input.
--[=[
	Validates a resource gain request.
	@within ResourceValidator
	@param resourceType string -- The resource being granted.
	@param amount number -- The amount being granted.
	@return Result.Result<nil> -- `Ok(nil)` when the grant is valid.
]=]
function ResourceValidator:ValidateEarn(resourceType: string, amount: number): Result.Result<nil>
	if not self:_IsKnownResourceType(resourceType) then
		return Err("UnknownResourceType", Errors.UNKNOWN_RESOURCE_TYPE)
	end

	if not self:_IsPositiveInteger(amount) then
		return Err("InvalidAmount", Errors.INVALID_AMOUNT)
	end

	return Ok(nil)
end

-- Validates a spend request against the current balance before any mutation occurs.
-- Keeping the balance check here preserves the command's no-partial-state guarantee.
--[=[
	Validates a resource spend request.
	@within ResourceValidator
	@param resourceType string -- The resource being spent.
	@param currentBalance number -- The wallet balance before the spend.
	@param cost number -- The amount being spent.
	@return Result.Result<nil> -- `Ok(nil)` when the spend is affordable.
]=]
function ResourceValidator:ValidateSpend(resourceType: string, currentBalance: number, cost: number): Result.Result<nil>
	if not self:_IsKnownResourceType(resourceType) then
		return Err("UnknownResourceType", Errors.UNKNOWN_RESOURCE_TYPE)
	end

	if not self:_IsPositiveInteger(cost) then
		return Err("InvalidAmount", Errors.INVALID_AMOUNT)
	end

	if currentBalance < cost then
		return Err("InsufficientResources", Errors.INSUFFICIENT_RESOURCES, {
			resourceType = resourceType,
			currentBalance = currentBalance,
			cost = cost,
		})
	end

	return Ok(nil)
end

--[=[
	Validates a multi-resource spend map against current wallet balances.
	@within ResourceValidator
	@param balances ResourceCostMap -- Current balances by resource name.
	@param costMap ResourceCostMap -- Requested costs by resource name.
	@return Result.Result<nil> -- `Ok(nil)` when every requested cost is affordable.
]=]
function ResourceValidator:ValidateSpendMap(balances: ResourceCostMap, costMap: ResourceCostMap): Result.Result<nil>
	if type(costMap) ~= "table" then
		return Err("InvalidCostMap", Errors.INVALID_COST_MAP)
	end

	local hasCost = false
	for resourceType, cost in costMap do
		if type(resourceType) ~= "string" or not self:_IsKnownResourceType(resourceType) then
			return Err("UnknownResourceType", Errors.UNKNOWN_RESOURCE_TYPE)
		end

		if type(cost) ~= "number" or not self:_IsPositiveInteger(cost) then
			return Err("InvalidAmount", Errors.INVALID_AMOUNT)
		end

		hasCost = true
		local currentBalance = balances[resourceType] or 0
		if currentBalance < cost then
			return Err("InsufficientResources", Errors.INSUFFICIENT_RESOURCES, {
				resourceType = resourceType,
				currentBalance = currentBalance,
				cost = cost,
			})
		end
	end

	if not hasCost then
		return Err("InvalidCostMap", Errors.INVALID_COST_MAP)
	end

	return Ok(nil)
end

-- Computes how much of an addition can be accepted before the resource cap wastes overflow.
-- The caller uses the returned value to avoid mutating past the configured cap.
--[=[
	Computes the accepted amount for a resource grant.
	@within ResourceValidator
	@param resourceType string -- The resource being granted.
	@param currentBalance number -- The current balance before the grant.
	@param amount number -- The requested grant amount.
	@return number -- The amount that can be safely applied.
]=]
function ResourceValidator:GetAcceptedAddition(resourceType: string, currentBalance: number, amount: number): number
	local cap = EconomyConfig.RESOURCE_CAPS[resourceType]
	if cap == nil then
		return amount
	end

	local remaining = cap - currentBalance
	if remaining <= 0 then
		return 0
	end

	if amount > remaining then
		return remaining
	end

	return amount
end

return ResourceValidator
