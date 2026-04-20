--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

--[=[
	@class GetLotBuildings
	Returns persisted building slot data for a player's lot.
	@server
]=]
local GetLotBuildings = {}
GetLotBuildings.__index = GetLotBuildings

export type TGetLotBuildings = typeof(setmetatable(
	{} :: {
		_persistenceService: any,
	},
	GetLotBuildings
))

--[=[
	@interface TSlotData
	@within GetLotBuildings
	.BuildingType string -- Building type key in the slot.
	.Level number -- Current persisted level in the slot.
]=]
export type TSlotData = {
	BuildingType: string,
	Level: number,
}

--[=[
	@type TLotBuildingsResult { [string]: { [number]: TSlotData } }
	@within GetLotBuildings
]=]
export type TLotBuildingsResult = {
	[string]: { [number]: TSlotData },
}

--[=[
	Create a lot buildings query instance.
	@within GetLotBuildings
	@return TGetLotBuildings -- New lot buildings query instance.
]=]
function GetLotBuildings.new(): TGetLotBuildings
	local self = setmetatable({}, GetLotBuildings)
	self._persistenceService = nil :: any
	return self
end

--[=[
	Initialize query dependencies from registry.
	@within GetLotBuildings
	@param registry any -- Context registry for dependency lookup.
	@param _name string -- Unused registration name.
]=]
function GetLotBuildings:Init(registry: any, _name: string)
	self._persistenceService = registry:Get("BuildingPersistenceService")
end

--[=[
	Get all buildings for the player's lot keyed by zone and slot.
	@within GetLotBuildings
	@param player Player -- Player whose lot buildings are requested.
	@return TLotBuildingsResult -- Persisted zone-slot building map.
]=]
function GetLotBuildings:Execute(player: Player): TLotBuildingsResult
	local buildings = self._persistenceService:GetAllBuildings(player)
	MentionSuccess("Building:GetLotBuildings:Execute", "Fetched persisted building map for player lot", {
		userId = player.UserId,
	})
	return buildings
end

return GetLotBuildings
