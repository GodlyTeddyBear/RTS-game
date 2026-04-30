--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type SpawnArea = WorldTypes.SpawnArea

--[=[
	@class GetSpawnAreasQuery
	Reads configured spawn areas from the authoritative world layout service.
	@server
]=]
local GetSpawnAreasQuery = {}
GetSpawnAreasQuery.__index = GetSpawnAreasQuery

--[=[
	Creates a query wrapper around the world layout service.
	@within GetSpawnAreasQuery
	@param worldLayoutService { GetSpawnAreas: (any) -> { SpawnArea } } -- Layout service dependency.
	@return GetSpawnAreasQuery -- The new query instance.
]=]
function GetSpawnAreasQuery.new(worldLayoutService: { GetSpawnAreas: (any) -> { SpawnArea } })
	local self = setmetatable({}, GetSpawnAreasQuery)
	self._worldLayoutService = worldLayoutService
	return self
end

--[=[
	Returns all configured spawn areas.
	@within GetSpawnAreasQuery
	@return { SpawnArea } -- The configured spawn areas.
]=]
function GetSpawnAreasQuery:Execute(): { SpawnArea }
	return self._worldLayoutService:GetSpawnAreas()
end

return GetSpawnAreasQuery
