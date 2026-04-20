--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)
local BuildingSpecs = require(script.Parent.Parent.Specs.BuildingSpecs)

--[=[
	@class UpgradePolicy
	Evaluates whether a slot's building can be upgraded.
	@server
]=]
local UpgradePolicy = {}
UpgradePolicy.__index = UpgradePolicy

export type TUpgradePolicy = typeof(setmetatable(
	{} :: {
		_buildingPersistenceService: any,
	},
	UpgradePolicy
))

--[=[
	@interface TUpgradePolicyResult
	@within UpgradePolicy
	.CurrentLevel number -- Current persisted building level.
	.BuildingType string -- Building type key in the slot.
]=]
export type TUpgradePolicyResult = {
	CurrentLevel: number,
	BuildingType: string,
}

--[=[
	Create an upgrade policy instance with deferred dependency wiring.
	@within UpgradePolicy
	@return TUpgradePolicy -- New upgrade policy instance.
]=]
function UpgradePolicy.new(): TUpgradePolicy
	local self = setmetatable({}, UpgradePolicy)
	self._buildingPersistenceService = nil :: any
	return self
end

--[=[
	Initialize persistence dependencies required for upgrade checks.
	@within UpgradePolicy
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function UpgradePolicy:Init(registry: any, _name: string)
	self._buildingPersistenceService = registry:Get("BuildingPersistenceService")
end

--[=[
	Validate whether upgrading can proceed for the requested slot.
	@within UpgradePolicy
	@param player Player -- Player attempting upgrade.
	@param zoneName string -- Zone containing the target slot.
	@param slotIndex number -- One-based target slot index.
	@return Result.Result<TUpgradePolicyResult> -- Success with slot level/type, or validation error.
]=]
function UpgradePolicy:Check(
	player: Player,
	zoneName: string,
	slotIndex: number
): Result.Result<TUpgradePolicyResult>
	local buildingData = self._buildingPersistenceService:GetSlotData(player, zoneName, slotIndex)
	local currentLevel = buildingData and buildingData.Level
	local buildingType = buildingData and buildingData.BuildingType

	local zoneDef = buildingType and BuildingConfig[zoneName]
	local buildingDef = zoneDef and zoneDef.Buildings[buildingType]

	local candidate: BuildingSpecs.TUpgradeCandidate = {
		HasBuilding = currentLevel ~= nil,
		BelowMaxLevel = buildingDef ~= nil and currentLevel ~= nil and currentLevel < buildingDef.MaxLevel,
	}

	Try(BuildingSpecs.CanUpgrade:IsSatisfiedBy(candidate))

	return Ok({
		CurrentLevel = currentLevel :: number,
		BuildingType = buildingType :: string,
	})
end

return UpgradePolicy
