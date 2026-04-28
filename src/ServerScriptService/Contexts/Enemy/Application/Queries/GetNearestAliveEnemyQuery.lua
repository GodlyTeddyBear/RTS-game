--!strict

local GetNearestAliveEnemyQuery = {}
GetNearestAliveEnemyQuery.__index = GetNearestAliveEnemyQuery

function GetNearestAliveEnemyQuery.new()
	return setmetatable({}, GetNearestAliveEnemyQuery)
end

function GetNearestAliveEnemyQuery:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EnemyEntityFactory")
end

function GetNearestAliveEnemyQuery:Execute(position: Vector3, maxRange: number): { Entity: number, CFrame: CFrame }?
	return self._entityFactory:GetNearestAliveEnemy(position, maxRange)
end

return GetNearestAliveEnemyQuery
