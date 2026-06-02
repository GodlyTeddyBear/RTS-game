--!strict

local SummonLifetimeSystem = {}
SummonLifetimeSystem.__index = SummonLifetimeSystem

function SummonLifetimeSystem.new(entityFactory: any, entityContext: any)
	local self = setmetatable({}, SummonLifetimeSystem)
	self._entityFactory = entityFactory
	self._entityContext = entityContext
	return self
end

function SummonLifetimeSystem:Run()
	-- READS: Entity.Lifetime [AUTHORITATIVE], Summon.DroneTag
	-- WRITES: Entity destruction queue
	local queryResult = self._entityFactory:Query({
		Keys = {
			{ Key = "ActiveTag", FeatureName = "Entity" },
			{ Key = "DroneTag", FeatureName = "Summon" },
			{ Key = "Lifetime", FeatureName = "Entity" },
		},
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(queryResult.value) do
		local lifetime = self:_Get(entity, "Lifetime", "Entity")
		if type(lifetime) == "table" and type(lifetime.ExpiresAt) == "number" and now >= lifetime.ExpiresAt then
			self._entityContext:DestroyEntity(entity)
		end
	end
end

function SummonLifetimeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return SummonLifetimeSystem
