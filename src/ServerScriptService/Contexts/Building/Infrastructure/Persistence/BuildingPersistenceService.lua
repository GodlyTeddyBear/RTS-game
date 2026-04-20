--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local Ok, Err = Result.Ok, Result.Err

--[=[
	@class BuildingPersistenceService
	Reads and writes building slot state in player profile production data.
	@server
]=]

--[=[
	@interface TSlotData
	@within BuildingPersistenceService
	.BuildingType string -- Building type key stored in slot.
	.Level number -- Current persisted building level.
]=]
type TSlotData = {
	BuildingType: string,
	Level: number,
}

local BuildingPersistenceService = {}
BuildingPersistenceService.__index = BuildingPersistenceService

export type TBuildingPersistenceService = typeof(setmetatable(
	{} :: {
		_profileManager: any,
	},
	BuildingPersistenceService
))

--[=[
	Create a persistence service with deferred profile manager wiring.
	@within BuildingPersistenceService
	@return TBuildingPersistenceService -- New persistence service instance.
]=]
function BuildingPersistenceService.new(): TBuildingPersistenceService
	local self = setmetatable({}, BuildingPersistenceService)
	self._profileManager = nil :: any
	return self
end

--[=[
	Initialize profile manager dependency for persistence operations.
	@within BuildingPersistenceService
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function BuildingPersistenceService:Init(registry: any, _name: string)
	self._profileManager = registry:Get("ProfileManager")
end

--[=[
	Get the building type occupying a slot.
	@within BuildingPersistenceService
	@param player Player -- Player owning the profile data.
	@param zoneName string -- Zone containing the slot.
	@param slotIndex number -- One-based slot index.
	@return string? -- Building type key, or `nil` when slot is empty.
]=]
function BuildingPersistenceService:GetSlotBuilding(player: Player, zoneName: string, slotIndex: number): string?
	local data = self._profileManager:GetData(player)
	if not data then
		return nil
	end
	local zoneTable = data.Production.Buildings[zoneName]
	if not zoneTable then
		return nil
	end
	local slotData: TSlotData? = zoneTable[slotIndex]
	return slotData and slotData.BuildingType or nil
end

--[=[
	Get full building slot data.
	@within BuildingPersistenceService
	@param player Player -- Player owning the profile data.
	@param zoneName string -- Zone containing the slot.
	@param slotIndex number -- One-based slot index.
	@return TSlotData? -- Slot building type and level, or `nil` when empty.
]=]
function BuildingPersistenceService:GetSlotData(player: Player, zoneName: string, slotIndex: number): TSlotData?
	local data = self._profileManager:GetData(player)
	if not data then
		return nil
	end
	local zoneTable = data.Production.Buildings[zoneName]
	if not zoneTable then
		return nil
	end
	return zoneTable[slotIndex]
end

--[=[
	Persist a newly constructed building in a slot.
	@within BuildingPersistenceService
	@param player Player -- Player owning the profile data.
	@param zoneName string -- Zone containing the slot.
	@param slotIndex number -- One-based slot index.
	@param buildingType string -- Building type key to persist.
	@return Result.Result<nil> -- Success when slot state is written.
]=]
function BuildingPersistenceService:SaveBuilding(
	player: Player,
	zoneName: string,
	slotIndex: number,
	buildingType: string
): Result.Result<nil>
	local data = self._profileManager:GetData(player)
	if not data then
		return Err("PROFILE_MISSING", "No profile data for player")
	end

	if not data.Production.Buildings[zoneName] then
		data.Production.Buildings[zoneName] = {}
	end

	data.Production.Buildings[zoneName][slotIndex] = {
		BuildingType = buildingType,
		Level = 1,
	}

	return Ok(nil)
end

--[=[
	Increment persisted level for an existing building slot.
	@within BuildingPersistenceService
	@param player Player -- Player owning the profile data.
	@param zoneName string -- Zone containing the slot.
	@param slotIndex number -- One-based slot index.
	@return Result.Result<nil> -- Success when level is incremented.
]=]
function BuildingPersistenceService:IncrementLevel(
	player: Player,
	zoneName: string,
	slotIndex: number
): Result.Result<nil>
	local data = self._profileManager:GetData(player)
	if not data then
		return Err("PROFILE_MISSING", "No profile data for player")
	end

	local zoneTable = data.Production.Buildings[zoneName]
	if not zoneTable or not zoneTable[slotIndex] then
		return Err("SLOT_EMPTY", "No building at this slot")
	end

	zoneTable[slotIndex].Level = zoneTable[slotIndex].Level + 1

	return Ok(nil)
end

--[=[
	Clear all persisted building and machine runtime entries for a player.
	@within BuildingPersistenceService
	@param player Player -- Player owning the profile data.
]=]
function BuildingPersistenceService:ClearAllForPlayer(player: Player)
	local data = self._profileManager:GetData(player)
	if not data then
		return
	end
	data.Production.Buildings = {}
	if data.Production.MachineRuntime then
		data.Production.MachineRuntime = {}
	end
end

--[=[
	Get all persisted buildings grouped by zone and slot.
	@within BuildingPersistenceService
	@param player Player -- Player owning the profile data.
	@return { [string]: { [number]: TSlotData } } -- Full building map for the player.
]=]
function BuildingPersistenceService:GetAllBuildings(player: Player): { [string]: { [number]: TSlotData } }
	local data = self._profileManager:GetData(player)
	if not data then
		return {}
	end
	return data.Production.Buildings or {}
end

return BuildingPersistenceService
