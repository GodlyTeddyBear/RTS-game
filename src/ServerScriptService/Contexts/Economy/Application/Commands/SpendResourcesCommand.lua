--!strict

--[[
	Module: SpendResourcesCommand
	Purpose: Validates and applies an atomic multi-resource spend against a player wallet.
	Used In System: Invoked by PlacementContext when structures require multiple resource costs.
	Boundaries: Owns command orchestration only; does not own affordability rules or atom mutation internals.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local EconomyTypes = require(ReplicatedStorage.Contexts.Economy.Types.EconomyTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try

type ResourceCostMap = EconomyTypes.ResourceCostMap

local SpendResourcesCommand = {}
SpendResourcesCommand.__index = SpendResourcesCommand

function SpendResourcesCommand.new()
	return setmetatable({}, SpendResourcesCommand)
end

function SpendResourcesCommand:Init(registry: any, _name: string)
	self._validator = registry:Get("ResourceValidator")
	self._syncService = registry:Get("ResourceSyncService")
end

function SpendResourcesCommand:Execute(userId: number, costMap: ResourceCostMap): Result.Result<nil>
	if type(costMap) ~= "table" then
		return Err("InvalidCostMap", Errors.INVALID_COST_MAP)
	end

	local balances = self._syncService:GetBalancesForCostMap(userId, costMap)
	if balances == nil then
		return Err("PlayerNotInitialized", Errors.PLAYER_NOT_INITIALIZED, {
			userId = userId,
		})
	end

	Try(self._validator:ValidateSpendMap(balances, costMap))
	self._syncService:SubtractResources(userId, costMap)

	Result.MentionSuccess("EconomyContext:SpendResourcesCommand", "Resources spent", {
		userId = userId,
		costMap = costMap,
	})

	return Ok(nil)
end

return SpendResourcesCommand
