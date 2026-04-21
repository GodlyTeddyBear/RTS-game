--!strict

--[=[
	@class GetAliveEnemiesQuery
	Returns all currently alive enemy entities.
	@server
]=]
local GetAliveEnemiesQuery = {}
GetAliveEnemiesQuery.__index = GetAliveEnemiesQuery

function GetAliveEnemiesQuery.new()
	return setmetatable({}, GetAliveEnemiesQuery)
end

function GetAliveEnemiesQuery:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
end

function GetAliveEnemiesQuery:Execute(): { number }
	return self._entityFactory:QueryAliveEntities()
end

return GetAliveEnemiesQuery
