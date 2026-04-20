--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Try = Result.Ok, Result.Try

local BuildingConfig = require(ReplicatedStorage.Contexts.Building.Config.BuildingConfig)
local BuildingSpecs = require(script.Parent.Parent.Specs.BuildingSpecs)

--[=[
	@class ConstructPolicy
	Evaluates whether a player can construct a building in a target slot.
	@server
]=]
local ConstructPolicy = {}
ConstructPolicy.__index = ConstructPolicy

export type TConstructPolicy = typeof(setmetatable(
	{} :: {
		_buildingPersistenceService: any,
		_currencyService: any,
		_unlockContext: any,
		_registry: any,
	},
	ConstructPolicy
))

--[=[
	@interface TConstructPolicyResult
	@within ConstructPolicy
	.PlayerGold number -- Player gold snapshot used during policy evaluation.
]=]
export type TConstructPolicyResult = {
	PlayerGold: number,
}

--[=[
	Create a construction policy instance with deferred dependency wiring.
	@within ConstructPolicy
	@return TConstructPolicy -- New construct policy instance.
]=]
function ConstructPolicy.new(): TConstructPolicy
	local self = setmetatable({}, ConstructPolicy)
	self._buildingPersistenceService = nil :: any
	self._currencyService = nil :: any
	self._unlockContext = nil :: any
	self._registry = nil :: any
	return self
end

--[=[
	Initialize infrastructure services required for eligibility checks.
	@within ConstructPolicy
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function ConstructPolicy:Init(registry: any, _name: string)
	self._buildingPersistenceService = registry:Get("BuildingPersistenceService")
	self._currencyService = registry:Get("BuildingCurrencyService")
	self._registry = registry
end

--[=[
	Resolve cross-context dependencies needed after ordered startup.
	@within ConstructPolicy
]=]
function ConstructPolicy:Start()
	self._unlockContext = self._registry:Get("UnlockContext")
end

--[=[
	Validate whether construction can proceed for the requested slot.
	@within ConstructPolicy
	@param player Player -- Player attempting construction.
	@param zoneName string -- Zone containing the target slot.
	@param slotIndex number -- One-based target slot index.
	@param buildingType string -- Building type key from config.
	@return Result.Result<TConstructPolicyResult> -- Success with policy state snapshot, or validation error.
]=]
function ConstructPolicy:Check(
	player: Player,
	zoneName: string,
	slotIndex: number,
	buildingType: string
): Result.Result<TConstructPolicyResult>
	-- Gather current slot occupancy and currency once for deterministic evaluation.
	local slotBuilding = self._buildingPersistenceService:GetSlotBuilding(player, zoneName, slotIndex)
	local playerGold = self._currencyService:GetGold(player)

	-- Resolve config and cost information used by candidate predicates.
	local zoneDef = BuildingConfig[zoneName]
	local buildingDef = zoneDef and zoneDef.Buildings[buildingType]
	local cost = buildingDef and (buildingDef.Cost.Gold or 0) or math.huge

	-- Check unlock status through the unlock context before constructing candidate.
	local targetId = zoneName .. "_" .. buildingType
	local isUnlocked = self._unlockContext:IsUnlocked(player.UserId, targetId)

	local candidate: BuildingSpecs.TConstructCandidate = {
		SlotIsEmpty = slotBuilding == nil,
		SlotInRange = zoneDef ~= nil and slotIndex >= 1 and slotIndex <= zoneDef.MaxSlots,
		BuildingTypeValid = buildingDef ~= nil,
		CanAfford = playerGold >= cost,
		IsUnlocked = isUnlocked,
	}

	Try(BuildingSpecs.CanConstruct:IsSatisfiedBy(candidate))

	return Ok({ PlayerGold = playerGold })
end

return ConstructPolicy
