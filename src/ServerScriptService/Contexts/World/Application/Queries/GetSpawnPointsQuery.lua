--!strict

--[=[
	@class GetSpawnPointsQuery
	Reads configured spawn points from the authoritative world layout service.
	@server
]=]
local GetSpawnPointsQuery = {}
GetSpawnPointsQuery.__index = GetSpawnPointsQuery

--[=[
	Creates a query wrapper around the world layout service.
	@within GetSpawnPointsQuery
	@param worldLayoutService { GetSpawnPoints: (any) -> { CFrame } } -- Layout service dependency.
	@return GetSpawnPointsQuery -- The new query instance.
]=]
function GetSpawnPointsQuery.new(worldLayoutService: { GetSpawnPoints: (any) -> { CFrame } })
	local self = setmetatable({}, GetSpawnPointsQuery)
	self._worldLayoutService = worldLayoutService
	return self
end

--[=[
	Returns all configured spawn points.
	@within GetSpawnPointsQuery
	@return { CFrame } -- The configured spawn points.
]=]
function GetSpawnPointsQuery:Execute()
	return self._worldLayoutService:GetSpawnPoints()
end

return GetSpawnPointsQuery
