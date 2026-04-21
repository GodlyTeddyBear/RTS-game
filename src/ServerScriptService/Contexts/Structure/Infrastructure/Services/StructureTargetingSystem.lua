--!strict

--[=[
	@class StructureTargetingSystem
	Acquires the nearest alive enemy for every active structure each tick.
	@server
]=]
local StructureTargetingSystem = {}
StructureTargetingSystem.__index = StructureTargetingSystem

--[=[
	Creates a new targeting system wrapper.
	@within StructureTargetingSystem
	@return StructureTargetingSystem -- The new system instance.
]=]
function StructureTargetingSystem.new()
	local self = setmetatable({}, StructureTargetingSystem)
	self._registry = nil
	self._factory = nil
	self._enemyContext = nil
	self._enemyEntityFactory = nil
	return self
end

--[=[
	Resolves the structure factory and keeps the registry for later cross-context lookups.
	@within StructureTargetingSystem
	@param registry any -- The dependency registry for this context.
	@param _name string -- The registered module name.
]=]
function StructureTargetingSystem:Init(registry: any, _name: string)
	self._registry = registry
	self._factory = registry:Get("StructureEntityFactory")
end

--[=[
	Caches the enemy context and its entity factory so tick work stays allocation-light.
	@within StructureTargetingSystem
]=]
function StructureTargetingSystem:Start()
	self._enemyContext = self._registry:Get("EnemyContext")

	local enemyEntityFactoryResult = self._enemyContext:GetEntityFactory()
	assert(enemyEntityFactoryResult.success, "StructureTargetingSystem failed to resolve EnemyEntityFactory")
	self._enemyEntityFactory = enemyEntityFactoryResult.value
end

--[=[
	Recomputes each structure's nearest enemy target from the current alive-enemy snapshot.
	@within StructureTargetingSystem
]=]
function StructureTargetingSystem:Tick()
	if self._enemyContext == nil or self._enemyEntityFactory == nil then
		return
	end

	-- Read the enemy list once so every structure works from the same snapshot this frame.
	local aliveEnemiesResult = self._enemyContext:GetAliveEnemies()
	if not aliveEnemiesResult.success then
		return
	end

	-- Cache enemy positions up front to avoid repeated factory reads inside the structure loop.
	local enemyPositionByEntity: { [number]: Vector3 } = {}
	for _, enemyEntity in ipairs(aliveEnemiesResult.value) do
		local position = self._enemyEntityFactory:GetPosition(enemyEntity)
		if position and position.cframe then
			enemyPositionByEntity[enemyEntity] = position.cframe.Position
		end
	end

	-- Evaluate each active structure independently so targeting stays stable per entity.
	for _, structureEntity in ipairs(self._factory:QueryActiveEntities()) do
		local attackStats = self._factory:GetAttackStats(structureEntity)
		local instanceRef = self._factory:GetInstanceRef(structureEntity)
		if attackStats == nil or instanceRef == nil then
			-- Missing components mean the entity is mid-teardown, so clear any stale target.
			self._factory:SetTarget(structureEntity, nil)
			continue
		end

		local nearestEnemy = nil :: number?
		local nearestDistanceSq = math.huge
		local maxDistanceSq = attackStats.AttackRange * attackStats.AttackRange

		-- Pick the closest enemy inside range so the attack system always sees one canonical target.
		for enemyEntity, enemyPos in pairs(enemyPositionByEntity) do
			local offset = enemyPos - instanceRef.WorldPos
			local distanceSq = offset:Dot(offset)
			if distanceSq <= maxDistanceSq and distanceSq < nearestDistanceSq then
				nearestDistanceSq = distanceSq
				nearestEnemy = enemyEntity
			end
		end

		self._factory:SetTarget(structureEntity, nearestEnemy)
	end
end

return StructureTargetingSystem
