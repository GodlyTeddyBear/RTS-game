--!strict

local FLEE_THRESHOLD = 0.2

--[=[
	@class CombatPerceptionService
	Builds the facts snapshot passed into combat behavior trees.
	@server
]=]
local CombatPerceptionService = {}
CombatPerceptionService.__index = CombatPerceptionService

--[=[
	@within CombatPerceptionService
	Creates a new combat perception service.
	@return CombatPerceptionService -- Service instance used to build behavior facts.
]=]
function CombatPerceptionService.new()
	return setmetatable({}, CombatPerceptionService)
end

--[=[
	@within CombatPerceptionService
	Resolves the enemy entity factory used to inspect path and health state.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatPerceptionService:Init(_registry: any, _name: string)
end

--[=[
	@within CombatPerceptionService
	Stores the enemy entity factory needed to build perception snapshots.
	@param registry any -- Registry instance used to resolve dependencies.
	@param _name string -- Registry key used to register the service.
]=]
function CombatPerceptionService:Start(registry: any, _name: string)
	self._enemyEntityFactory = registry:Get("EnemyEntityFactory")
	self._structureEntityFactory = registry:Get("StructureEntityFactory")
end

function CombatPerceptionService:_FindNearestStructureInRange(enemyPosition: Vector3, attackRange: number): number?
	if self._structureEntityFactory == nil then
		return nil
	end

	local nearestStructure = nil :: number?
	local nearestDistanceSq = math.huge
	local maxDistanceSq = attackRange * attackRange

	for _, structureEntity in ipairs(self._structureEntityFactory:QueryActiveEntities()) do
		local structurePosition = self._structureEntityFactory:GetPosition(structureEntity)
		if structurePosition == nil then
			continue
		end

		local offset = structurePosition - enemyPosition
		local distanceSq = offset:Dot(offset)
		if distanceSq <= maxDistanceSq and distanceSq < nearestDistanceSq then
			nearestDistanceSq = distanceSq
			nearestStructure = structureEntity
		end
	end

	return nearestStructure
end

function CombatPerceptionService:_FindNearestEnemyInRange(structurePosition: Vector3, attackRange: number): number?
	local nearestEnemy = nil :: number?
	local nearestDistanceSq = math.huge
	local maxDistanceSq = attackRange * attackRange

	for _, enemyEntity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
		local position = self._enemyEntityFactory:GetPosition(enemyEntity)
		if position == nil then
			continue
		end

		local offset = position.cframe.Position - structurePosition
		local distanceSq = offset:Dot(offset)
		if distanceSq <= maxDistanceSq and distanceSq < nearestDistanceSq then
			nearestDistanceSq = distanceSq
			nearestEnemy = enemyEntity
		end
	end

	return nearestEnemy
end

--[=[
	@within CombatPerceptionService
	Returns the perception facts a behavior tree needs to decide the next action.
	@param entity number -- Enemy entity id whose state should be sampled.
	@param _currentTime number -- Current timestamp, reserved for future time-based facts.
	@return table -- Facts snapshot consumed by combat behavior trees.
]=]
function CombatPerceptionService:BuildSnapshot(entity: number, _currentTime: number)
	local pathState = self._enemyEntityFactory:GetPathState(entity)
	local health = self._enemyEntityFactory:GetHealth(entity)
	local role = self._enemyEntityFactory:GetRole(entity)
	local position = self._enemyEntityFactory:GetPosition(entity)

	local hasGoalTarget = pathState ~= nil and pathState.goalPosition ~= nil

	local healthPct = 1
	if health and health.max > 0 then
		healthPct = math.clamp(health.current / health.max, 0, 1)
	end

	local targetStructureEntity = nil :: number?
	if role and position and position.cframe and type(role.attackRange) == "number" then
		targetStructureEntity = self:_FindNearestStructureInRange(position.cframe.Position, role.attackRange)
	end

	return {
		HasGoalTarget = hasGoalTarget,
		HealthPct = healthPct,
		ShouldFlee = healthPct < FLEE_THRESHOLD,
		TargetStructureEntity = targetStructureEntity,
	}
end

function CombatPerceptionService:BuildStructureSnapshot(entity: number, _currentTime: number)
	local attackStats = self._structureEntityFactory:GetAttackStats(entity)
	local position = self._structureEntityFactory:GetPosition(entity)

	local targetEnemyEntity = nil :: number?
	if attackStats ~= nil and position ~= nil then
		targetEnemyEntity = self:_FindNearestEnemyInRange(position, attackStats.AttackRange)
	end

	return {
		TargetEnemyEntity = targetEnemyEntity,
	}
end

return CombatPerceptionService
