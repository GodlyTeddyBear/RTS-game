--!strict

local EntityLifetimeExpirySystem = {}
EntityLifetimeExpirySystem.__index = EntityLifetimeExpirySystem

function EntityLifetimeExpirySystem.new(entityFactory: any)
	return setmetatable({ _entityFactory = entityFactory }, EntityLifetimeExpirySystem)
end

function EntityLifetimeExpirySystem:Run()
	-- READS: Entity.ActiveTag [AUTHORITATIVE], Entity.Lifetime [AUTHORITATIVE]
	-- WRITES: Entity.DestructionQueue
	local result = self._entityFactory:Query({ FeatureName = "Entity", Keys = { "ActiveTag", "Lifetime" } })
	if not result.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(result.value) do
		local lifetime = self:_Get(entity, "Lifetime", "Entity")
		local expiresAt = if type(lifetime) == "table" then lifetime.ExpiresAt else nil
		if type(expiresAt) == "number" and now >= expiresAt then
			self._entityFactory:MarkEntityForDestruction(entity)
		end
	end
end

function EntityLifetimeExpirySystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EntityLifetimeExpirySystem
