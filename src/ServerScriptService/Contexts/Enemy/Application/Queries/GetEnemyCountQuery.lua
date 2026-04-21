--!strict

--[=[
	@class GetEnemyCountQuery
	Returns the current number of alive enemy entities.
	@server
]=]
local GetEnemyCountQuery = {}
GetEnemyCountQuery.__index = GetEnemyCountQuery

function GetEnemyCountQuery.new()
	return setmetatable({}, GetEnemyCountQuery)
end

function GetEnemyCountQuery:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
end

function GetEnemyCountQuery:Execute(): number
	return #self._entityFactory:QueryAliveEntities()
end

return GetEnemyCountQuery
