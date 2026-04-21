--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try

--[=[
	@class AddResourceCommand
	Validates and applies a resource grant to a player wallet.
	@server
]=]
local AddResourceCommand = {}
AddResourceCommand.__index = AddResourceCommand

-- Creates the add-resource command with no constructor dependencies.
--[=[
	Creates a new add-resource command.
	@within AddResourceCommand
	@return AddResourceCommand -- The new command instance.
]=]
function AddResourceCommand.new()
	return setmetatable({}, AddResourceCommand)
end

-- Resolves the validator and sync service from the registry so the command stays thin.
--[=[
	Initializes command dependencies.
	@within AddResourceCommand
	@param registry any -- The registry that owns this command.
	@param _name string -- The registered module name.
]=]
function AddResourceCommand:Init(registry: any, _name: string)
	self._validator = registry:Get("ResourceValidator")
	self._syncService = registry:Get("ResourceSyncService")
end

-- Validates first, then applies the capped grant so no partial mutation occurs on bad input.
--[=[
	Executes the add-resource command.
	@within AddResourceCommand
	@param userId number -- The target player user id.
	@param resourceType string -- The resource to add.
	@param amount number -- The requested grant amount.
	@return Result.Result<nil> -- `Ok(nil)` when the grant is accepted.
]=]
function AddResourceCommand:Execute(userId: number, resourceType: string, amount: number): Result.Result<nil>
	-- Resolve the current balance before validation so cap logic can compute accepted overflow.
	local currentBalance = self._syncService:GetBalance(userId, resourceType)
	if currentBalance == nil then
		return Err("PlayerNotInitialized", Errors.PLAYER_NOT_INITIALIZED, {
			userId = userId,
		})
	end

	-- Reject malformed grants before touching the sync atom.
	Try(self._validator:ValidateEarn(resourceType, amount))

	-- Apply the capped grant and ignore overflow, which is wasted by design.
	local acceptedAmount = self._validator:GetAcceptedAddition(resourceType, currentBalance, amount)
	if acceptedAmount > 0 then
		self._syncService:AddResource(userId, resourceType, acceptedAmount)
	end

	-- Record the successful grant for telemetry.
	Result.MentionSuccess("EconomyContext:AddResourceCommand", "Resource earned", {
		userId = userId,
		resourceType = resourceType,
		amount = amount,
		acceptedAmount = acceptedAmount,
	})

	return Ok(nil)
end

return AddResourceCommand
