--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)

--[=[
	@class GetAliveEnemiesQuery
	Returns all currently alive enemy entities.
	@server
]=]
local GetAliveEnemiesQuery = {}
GetAliveEnemiesQuery.__index = GetAliveEnemiesQuery
setmetatable(GetAliveEnemiesQuery, BaseQuery)

function GetAliveEnemiesQuery.new()
	local self = BaseQuery.new("Enemy", "GetAliveEnemiesQuery")
	return setmetatable(self, GetAliveEnemiesQuery)
end

function GetAliveEnemiesQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityFactory", "EnemyEntityFactory")
end

function GetAliveEnemiesQuery:Execute(): { number }
	return self._entityFactory:QueryAliveEntities()
end

return GetAliveEnemiesQuery
