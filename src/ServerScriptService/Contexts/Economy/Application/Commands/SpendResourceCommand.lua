--!strict

--[[
	Module: SpendResourceCommand
	Purpose: Validates and applies a resource spend against a player wallet.
	Used In System: Invoked by EconomyContext and other server-side deduction flows when resources are consumed.
	Boundaries: Owns command orchestration only; does not own affordability rules, sync mutation, or persistence.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try

-- [Initialization]

--[=[
	@class SpendResourceCommand
	Validates and applies a resource spend against a player wallet.
	@server
]=]
local SpendResourceCommand = {}
SpendResourceCommand.__index = SpendResourceCommand

-- Creates the spend-resource command with no constructor dependencies.
--[=[
	Creates a new spend-resource command.
	@within SpendResourceCommand
	@return SpendResourceCommand -- The new command instance.
]=]
function SpendResourceCommand.new()
	return setmetatable({}, SpendResourceCommand)
end

-- [Public API]

-- Resolves the validator and sync service from the registry so the command stays thin.
--[=[
	Initializes command dependencies.
	@within SpendResourceCommand
	@param registry any -- The registry that owns this command.
	@param _name string -- The registered module name.
]=]
function SpendResourceCommand:Init(registry: any, _name: string)
	self._validator = registry:Get("ResourceValidator")
	self._syncService = registry:Get("ResourceSyncService")
end

-- Checks the live balance first, then validates the request, then mutates the wallet.
--[=[
	Executes the spend-resource command.
	@within SpendResourceCommand
	@param userId number -- The target player user id.
	@param resourceType string -- The resource to spend.
	@param cost number -- The requested spend amount.
	@return Result.Result<nil> -- `Ok(nil)` when the spend is accepted.
]=]
function SpendResourceCommand:Execute(userId: number, resourceType: string, cost: number): Result.Result<nil>
	-- Read the current balance before validation so the validator can enforce affordability.
	local currentBalance = self._syncService:GetBalance(userId, resourceType)
	if currentBalance == nil then
		return Err("PlayerNotInitialized", Errors.PLAYER_NOT_INITIALIZED, {
			userId = userId,
		})
	end

	-- Reject invalid or unaffordable spends before any mutation occurs.
	Try(self._validator:ValidateSpend(resourceType, currentBalance, cost))

	-- Apply the deduction only after validation succeeds.
	self._syncService:SubtractResource(userId, resourceType, cost)

	-- Record the successful spend for telemetry.
	Result.MentionSuccess("EconomyContext:SpendResourceCommand", "Resource spent", {
		userId = userId,
		resourceType = resourceType,
		cost = cost,
	})

	return Ok(nil)
end

return SpendResourceCommand
