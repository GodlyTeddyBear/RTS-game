--!strict

--[=[
	@class GetGoalReachedEnemiesQuery
	Returns entities marked as goal reached in the current run.
	@server
]=]
local GetGoalReachedEnemiesQuery = {}
GetGoalReachedEnemiesQuery.__index = GetGoalReachedEnemiesQuery

function GetGoalReachedEnemiesQuery.new()
	return setmetatable({}, GetGoalReachedEnemiesQuery)
end

function GetGoalReachedEnemiesQuery:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
end

function GetGoalReachedEnemiesQuery:Execute(): { number }
	return self._entityFactory:QueryGoalReachedEntities()
end

return GetGoalReachedEnemiesQuery
