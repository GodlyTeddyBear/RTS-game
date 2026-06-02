--!strict

local BaseDamageResolveSystem = {}
BaseDamageResolveSystem.__index = BaseDamageResolveSystem

function BaseDamageResolveSystem.new(entityFactory: any, baseContext: any)
	return setmetatable({ _entityFactory = entityFactory, _baseContext = baseContext }, BaseDamageResolveSystem)
end

function BaseDamageResolveSystem:Run()
	-- READS: Combat.BaseDamageRequest [AUTHORITATIVE]
	-- WRITES: Combat.ProcessedTag
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "BaseDamageRequest", "RequestTag" } })
	if not result.success then return end
	for _, entity in ipairs(result.value) do
		local request = self:_Get(entity, "BaseDamageRequest", "Combat")
		if type(request) == "table" and type(request.Amount) == "number" and request.Amount > 0 then
			self._baseContext:ApplyDamage(request.Amount)
		end
		self._entityFactory:Add(entity, "ProcessedTag", "Combat")
	end
end

function BaseDamageResolveSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return BaseDamageResolveSystem
