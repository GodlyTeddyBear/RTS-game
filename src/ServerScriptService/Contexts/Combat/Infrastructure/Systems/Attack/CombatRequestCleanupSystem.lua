--!strict

local CombatRequestCleanupSystem = {}
CombatRequestCleanupSystem.__index = CombatRequestCleanupSystem

function CombatRequestCleanupSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, CombatRequestCleanupSystem)
	self._entityFactory = entityFactory
	self._hitboxSimulation = dependencies.HitboxSimulation
	self._projectileSimulation = dependencies.ProjectileSimulation
	return self
end

function CombatRequestCleanupSystem:Run()
	local processed = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "RequestTag", "ProcessedTag" } })
	if processed.success then
		for _, entity in ipairs(processed.value) do
			if self:_IsAttackRequest(entity) then
				self._entityFactory:MarkEntityForDestruction(entity)
			end
		end
	end
	self:_CleanupExpired("HitboxSpawnRequest")
	self:_CleanupExpired("GoalReachedOutcomeRequest")
	self:_CleanupExpired("BaseDamageRequest")
	self:_CleanupExpired("ProjectileSpawnRequest")
	self:_CleanupHitboxes()
	self:_CleanupProjectiles()
end

function CombatRequestCleanupSystem:_IsAttackRequest(entity: number): boolean
	return self:_Get(entity, "HitboxSpawnRequest", "Combat") ~= nil
		or self:_Get(entity, "GoalReachedOutcomeRequest", "Combat") ~= nil
		or self:_Get(entity, "BaseDamageRequest", "Combat") ~= nil
		or self:_Get(entity, "ProjectileSpawnRequest", "Combat") ~= nil
end

function CombatRequestCleanupSystem:_CleanupProjectiles()
	local completed = {}
	for _, handle in ipairs(self._projectileSimulation:DrainCompletedHandles()) do
		completed[handle] = true
	end
	if next(completed) == nil then return end
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "ActiveProjectileState" } })
	if not result.success then return end
	for _, entity in ipairs(result.value) do
		local state = self:_Get(entity, "ActiveProjectileState", "Combat")
		if type(state) == "table" and completed[state.Handle] == true then
			self._entityFactory:MarkEntityForDestruction(entity)
		end
	end
end

function CombatRequestCleanupSystem:_CleanupExpired(key: string)
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "RequestTag", key } })
	if not result.success then return end
	local now = os.clock()
	for _, entity in ipairs(result.value) do
		local request = self:_Get(entity, key, "Combat")
		if type(request) == "table" and type(request.ExpiresAt) == "number" and now >= request.ExpiresAt then
			self._entityFactory:MarkEntityForDestruction(entity)
		end
	end
end

function CombatRequestCleanupSystem:_CleanupHitboxes()
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "ActiveHitboxState" } })
	if not result.success then return end
	local now = os.clock()
	for _, entity in ipairs(result.value) do
		local state = self:_Get(entity, "ActiveHitboxState", "Combat")
		if type(state) == "table" and type(state.ExpiresAt) == "number" and now >= state.ExpiresAt then
			if type(state.Handle) == "string" then self._hitboxSimulation:DestroyHandle(state.Handle) end
			self._entityFactory:MarkEntityForDestruction(entity)
		end
	end
end

function CombatRequestCleanupSystem:_Get(entity: number, key: string, feature: string): any
	local result = self._entityFactory:Get(entity, key, feature)
	return if result.success then result.value else nil
end

return CombatRequestCleanupSystem
