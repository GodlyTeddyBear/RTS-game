--!strict

local EnemyRequestCleanupSystem = {}
EnemyRequestCleanupSystem.__index = EnemyRequestCleanupSystem

function EnemyRequestCleanupSystem.new(entityFactory: any)
	return setmetatable({
		_entityFactory = entityFactory,
	}, EnemyRequestCleanupSystem)
end

function EnemyRequestCleanupSystem:Run()
	local processed = self._entityFactory:Query({ FeatureName = "Enemy", Keys = { "RequestTag", "ProcessedTag" } })
	if processed.success then
		for _, entity in ipairs(processed.value) do
			self._entityFactory:MarkEntityForDestruction(entity)
		end
	end

	self:_CleanupExpired("DeathEventRequest")
end

function EnemyRequestCleanupSystem:_CleanupExpired(key: string)
	local result = self._entityFactory:Query({ FeatureName = "Enemy", Keys = { "RequestTag", key } })
	if not result.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(result.value) do
		local request = self:_Get(entity, key, "Enemy")
		if type(request) == "table" and type(request.ExpiresAt) == "number" and now >= request.ExpiresAt then
			self._entityFactory:MarkEntityForDestruction(entity)
		end
	end
end

function EnemyRequestCleanupSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EnemyRequestCleanupSystem
