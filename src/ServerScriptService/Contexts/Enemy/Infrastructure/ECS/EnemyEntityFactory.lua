--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EnemyConfig = require(ReplicatedStorage.Contexts.Enemy.Config.EnemyConfig)

--[=[
	@class EnemyEntityFactory
	Creates and mutates enemy entities in the EnemyContext ECS world.
	@server
]=]
local EnemyEntityFactory = {}
EnemyEntityFactory.__index = EnemyEntityFactory

function EnemyEntityFactory.new()
	return setmetatable({}, EnemyEntityFactory)
end

function EnemyEntityFactory:Init(registry: any, _name: string)
	self._world = registry:Get("World")
	self._components = registry:Get("EnemyComponentRegistry"):GetComponents()
end

function EnemyEntityFactory:CreateEnemy(enemyId: string, role: string, spawnCFrame: CFrame, waveNumber: number): number
	local roleConfig = EnemyConfig.ROLES[role]
	assert(roleConfig ~= nil, "Unknown enemy role: " .. tostring(role))
	local entity = self._world:entity()

	self._world:set(entity, self._components.Health, {
		current = roleConfig.maxHp,
		max = roleConfig.maxHp,
	})
	self._world:set(entity, self._components.Position, {
		cframe = spawnCFrame,
	})
	self._world:set(entity, self._components.Role, {
		role = role,
		moveSpeed = roleConfig.moveSpeed,
		damage = roleConfig.damage,
		targetPreference = roleConfig.targetPreference,
	})
	self._world:set(entity, self._components.PathState, {
		waypointIndex = 1,
		waypoints = {},
		isMoving = false,
	})
	self._world:set(entity, self._components.Identity, {
		enemyId = enemyId,
		role = role,
		waveNumber = waveNumber,
	})
	self._world:add(entity, self._components.AliveTag)

	return entity
end

function EnemyEntityFactory:SetModelRef(entity: number, model: Model)
	self._world:set(entity, self._components.ModelRef, { model = model })
	self._world:add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:SetWaypoints(entity: number, waypoints: { Vector3 })
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self._world:set(entity, self._components.PathState, {
		waypointIndex = 1,
		waypoints = table.clone(waypoints),
		isMoving = false,
	})
end

function EnemyEntityFactory:SetPathMoving(entity: number, isMoving: boolean)
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self._world:set(entity, self._components.PathState, {
		waypointIndex = state.waypointIndex,
		waypoints = state.waypoints,
		isMoving = isMoving,
	})
end

function EnemyEntityFactory:SetWaypointIndex(entity: number, waypointIndex: number)
	local state = self:GetPathState(entity)
	if state == nil then
		return
	end

	self._world:set(entity, self._components.PathState, {
		waypointIndex = waypointIndex,
		waypoints = state.waypoints,
		isMoving = state.isMoving,
	})
end

function EnemyEntityFactory:MarkGoalReached(entity: number)
	self._world:remove(entity, self._components.AliveTag)
	self._world:add(entity, self._components.GoalReachedTag)
	self._world:add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:ClearGoalReached(entity: number)
	self._world:remove(entity, self._components.GoalReachedTag)
	self._world:add(entity, self._components.DirtyTag)
end

function EnemyEntityFactory:ApplyDamage(entity: number, amount: number): boolean
	local health = self:GetHealth(entity)
	if health == nil then
		return false
	end

	local nextHp = math.max(0, health.current - amount)
	self._world:set(entity, self._components.Health, {
		current = nextHp,
		max = health.max,
	})
	self._world:add(entity, self._components.DirtyTag)

	return nextHp <= 0
end

function EnemyEntityFactory:UpdatePosition(entity: number, cframe: CFrame)
	self._world:set(entity, self._components.Position, { cframe = cframe })
end

function EnemyEntityFactory:GetDeathCFrame(entity: number): CFrame?
	local modelRef = self:GetModelRef(entity)
	if modelRef ~= nil then
		return modelRef.model:GetPivot()
	end

	local position = self:GetPosition(entity)
	if position ~= nil then
		return position.cframe
	end

	return nil
end

function EnemyEntityFactory:IsAlive(entity: number): boolean
	return self._world:has(entity, self._components.AliveTag)
end

function EnemyEntityFactory:GetHealth(entity: number)
	return self._world:get(entity, self._components.Health)
end

function EnemyEntityFactory:GetRole(entity: number)
	return self._world:get(entity, self._components.Role)
end

function EnemyEntityFactory:GetIdentity(entity: number)
	return self._world:get(entity, self._components.Identity)
end

function EnemyEntityFactory:GetPathState(entity: number)
	return self._world:get(entity, self._components.PathState)
end

function EnemyEntityFactory:GetModelRef(entity: number)
	return self._world:get(entity, self._components.ModelRef)
end

function EnemyEntityFactory:GetPosition(entity: number)
	return self._world:get(entity, self._components.Position)
end

function EnemyEntityFactory:QueryAliveEntities(): { number }
	local entities = {}
	for entity in self._world:query(self._components.AliveTag) do
		table.insert(entities, entity)
	end
	return entities
end

function EnemyEntityFactory:QueryGoalReachedEntities(): { number }
	local entities = {}
	for entity in self._world:query(self._components.GoalReachedTag) do
		table.insert(entities, entity)
	end
	return entities
end

function EnemyEntityFactory:DeleteEntity(entity: number)
	self._world:delete(entity)
end

return EnemyEntityFactory
