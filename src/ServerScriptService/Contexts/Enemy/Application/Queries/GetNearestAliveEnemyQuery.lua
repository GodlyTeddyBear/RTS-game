--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseQuery = require(ReplicatedStorage.Utilities.BaseApplication.BaseQuery)

local GetNearestAliveEnemyQuery = {}
GetNearestAliveEnemyQuery.__index = GetNearestAliveEnemyQuery
setmetatable(GetNearestAliveEnemyQuery, BaseQuery)

function GetNearestAliveEnemyQuery.new()
	local self = BaseQuery.new("Enemy", "GetNearestAliveEnemyQuery")
	return setmetatable(self, GetNearestAliveEnemyQuery)
end

function GetNearestAliveEnemyQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityFactory", "EnemyEntityFactory")
end

function GetNearestAliveEnemyQuery:Execute(position: Vector3, maxRange: number): { Entity: number, CFrame: CFrame }?
	return self._entityFactory:GetNearestAliveEnemy(position, maxRange)
end

return GetNearestAliveEnemyQuery
