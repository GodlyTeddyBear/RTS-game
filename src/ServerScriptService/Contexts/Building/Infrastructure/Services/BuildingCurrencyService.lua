--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err = Result.Ok, Result.Err

local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)

--[=[
	@class BuildingCurrencyService
	Reads and deducts construction currency from player profile data.
	@server
]=]
local BuildingCurrencyService = {}
BuildingCurrencyService.__index = BuildingCurrencyService

export type TBuildingCurrencyService = typeof(setmetatable(
	{} :: {
		_profileManager: any,
	},
	BuildingCurrencyService
))

--[=[
	Create a currency adapter with deferred profile manager wiring.
	@within BuildingCurrencyService
	@return TBuildingCurrencyService -- New currency service instance.
]=]
function BuildingCurrencyService.new(): TBuildingCurrencyService
	local self = setmetatable({}, BuildingCurrencyService)
	self._profileManager = nil :: any
	return self
end

--[=[
	Initialize registry dependencies used for profile reads and writes.
	@within BuildingCurrencyService
	@param registry any -- Context registry that owns ProfileManager.
	@param _name string -- Unused registration name.
]=]
function BuildingCurrencyService:Init(registry: any, _name: string)
	self._profileManager = registry:Get("ProfileManager")
end

--[=[
	Get the current gold balance for a player profile.
	@within BuildingCurrencyService
	@param player Player -- Player whose profile balance is read.
	@return number -- Gold amount, or `0` when profile is unavailable.
]=]
function BuildingCurrencyService:GetGold(player: Player): number
	local data = self._profileManager:GetData(player)
	if not data then
		return 0
	end
	return data.Gold or 0
end

--[=[
	Deduct configured construction cost from player gold.
	@within BuildingCurrencyService
	@param player Player -- Player paying for construction.
	@param zoneName string -- Zone name for building config lookup.
	@param buildingType string -- Building type key for cost lookup.
	@return Result.Result<nil> -- Success when cost is deducted, error otherwise.
]=]
function BuildingCurrencyService:DeductConstructionCost(
	player: Player,
	zoneName: string,
	buildingType: string
): Result.Result<nil>
	-- Load profile once so all checks and mutation use one authoritative snapshot.
	local data = self._profileManager:GetData(player)
	if not data then
		return Err("PROFILE_MISSING", "No profile for player")
	end

	-- Resolve zone and building definitions before touching currency.
	local zoneDef = BuildingConfig[zoneName]
	if not zoneDef then
		return Err("INVALID_ZONE", "Zone not found in config")
	end

	local buildingDef = zoneDef.Buildings[buildingType]
	if not buildingDef then
		return Err("UNKNOWN_BUILDING_TYPE", "Building not found in config")
	end

	-- Enforce affordability before mutating player gold.
	local cost = buildingDef.Cost.Gold or 0
	if data.Gold < cost then
		return Err("CANNOT_AFFORD", "Insufficient gold")
	end

	data.Gold -= cost
	return Ok(nil)
end

return BuildingCurrencyService
