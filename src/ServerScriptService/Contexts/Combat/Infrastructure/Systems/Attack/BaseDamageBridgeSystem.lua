--!strict

local BaseDamageBridgeSystem = {}
BaseDamageBridgeSystem.__index = BaseDamageBridgeSystem

function BaseDamageBridgeSystem.new(entityFactory: any, baseContext: any)
	return setmetatable({ _entityFactory = entityFactory, _baseContext = baseContext }, BaseDamageBridgeSystem)
end

function BaseDamageBridgeSystem:Run()
	-- READS: Combat.BaseDamageRequest [AUTHORITATIVE]
	-- WRITES: Combat.HealthChangeRequest, Combat.ProcessedTag
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "BaseDamageRequest", "RequestTag" } })
	if not result.success then return end
	for _, entity in ipairs(result.value) do
		local request = self:_Get(entity, "BaseDamageRequest", "Combat")
		if type(request) == "table" and type(request.Amount) == "number" and request.Amount > 0 then
			local baseEntity = self:_GetActiveBaseEntity()
			if type(baseEntity) == "number" then
				local now = os.clock()
				self._entityFactory:CreateFromArchetype("Combat.HealthChangeRequest", {
					HealthChangeRequest = {
						SourceEntity = nil,
						TargetEntity = baseEntity,
						TargetKind = "Base",
						Amount = request.Amount,
						ChangeType = "Damage",
						CreatedAt = now,
						ExpiresAt = now + 1,
						Reason = "BaseDamageRequest",
					},
				})
			end
		end
		self._entityFactory:Add(entity, "ProcessedTag", "Combat")
	end
end

function BaseDamageBridgeSystem:_GetActiveBaseEntity(): number?
	local result = self._entityFactory:Query({
		Keys = {
			{ Key = "BaseTag", FeatureName = "Base" },
			{ Key = "ActiveTag", FeatureName = "Entity" },
		},
	})
	if not result.success then
		return nil
	end
	return result.value[1]
end

function BaseDamageBridgeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return BaseDamageBridgeSystem
