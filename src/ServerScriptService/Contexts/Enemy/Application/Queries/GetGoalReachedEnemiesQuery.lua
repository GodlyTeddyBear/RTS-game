--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)

--[=[
	@class GetGoalReachedEnemiesQuery
	Returns entities marked as goal reached in the current run.
	@server
]=]
local GetGoalReachedEnemiesQuery = {}
GetGoalReachedEnemiesQuery.__index = GetGoalReachedEnemiesQuery
setmetatable(GetGoalReachedEnemiesQuery, BaseQuery)

function GetGoalReachedEnemiesQuery.new()
	local self = BaseQuery.new("Enemy", "GetGoalReachedEnemiesQuery")
	return setmetatable(self, GetGoalReachedEnemiesQuery)
end

function GetGoalReachedEnemiesQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityFactory", "EnemyEntityFactory")
end

function GetGoalReachedEnemiesQuery:Execute(): { number }
	return self._entityFactory:QueryGoalReachedEntities()
end

return GetGoalReachedEnemiesQuery
