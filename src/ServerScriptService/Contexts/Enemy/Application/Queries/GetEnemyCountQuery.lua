--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)

--[=[
	@class GetEnemyCountQuery
	Returns the current number of alive enemy entities.
	@server
]=]
local GetEnemyCountQuery = {}
GetEnemyCountQuery.__index = GetEnemyCountQuery
setmetatable(GetEnemyCountQuery, BaseQuery)

function GetEnemyCountQuery.new()
	local self = BaseQuery.new("Enemy", "GetEnemyCountQuery")
	return setmetatable(self, GetEnemyCountQuery)
end

function GetEnemyCountQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityFactory", "EnemyEntityFactory")
end

function GetEnemyCountQuery:Execute(): number
	return #self._entityFactory:QueryAliveEntities()
end

return GetEnemyCountQuery
