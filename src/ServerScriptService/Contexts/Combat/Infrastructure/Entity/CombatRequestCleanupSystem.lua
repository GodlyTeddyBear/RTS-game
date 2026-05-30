--!strict

local CombatRequestCleanupSystem = {}
CombatRequestCleanupSystem.__index = CombatRequestCleanupSystem

function CombatRequestCleanupSystem.new(entityFactory: any)
	local self = setmetatable({}, CombatRequestCleanupSystem)
	self._entityFactory = entityFactory
	return self
end

function CombatRequestCleanupSystem:Run()
	-- READS: Combat.RequestTag, Combat.ProcessedTag, Combat.HitboxRequest [AUTHORITATIVE], Combat.DamageRequest [AUTHORITATIVE]
	-- WRITES: Entity destruction queue
	local processedResult = self._entityFactory:Query({
		FeatureName = "Combat",
		Keys = { "RequestTag", "ProcessedTag" },
	})
	if processedResult.success then
		for _, requestEntity in ipairs(processedResult.value) do
			self._entityFactory:MarkEntityForDestruction(requestEntity)
		end
	end

	self:_MarkExpiredRequests("HitboxRequest")
	self:_MarkExpiredRequests("DamageRequest")
end

function CombatRequestCleanupSystem:_MarkExpiredRequests(componentKey: string)
	local queryResult = self._entityFactory:Query({
		FeatureName = "Combat",
		Keys = { "RequestTag", componentKey },
	})
	if not queryResult.success then
		return
	end

	local now = os.clock()
	for _, requestEntity in ipairs(queryResult.value) do
		local request = self:_Get(requestEntity, componentKey, "Combat")
		if type(request) == "table" and type(request.ExpiresAt) == "number" and now >= request.ExpiresAt then
			self._entityFactory:MarkEntityForDestruction(requestEntity)
		end
	end
end

function CombatRequestCleanupSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return CombatRequestCleanupSystem
