--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)

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
	self:_RequireDependency(registry, "_enemyEntityReadService", "EnemyEntityReadService")
end

function GetAliveEnemiesQuery:Execute(): { number }
	return self._enemyEntityReadService:QueryAliveEntities()
end

return GetAliveEnemiesQuery
