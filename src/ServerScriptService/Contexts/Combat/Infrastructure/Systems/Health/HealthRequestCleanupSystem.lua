--!strict

local HealthRequestCleanupSystem = {}
HealthRequestCleanupSystem.__index = HealthRequestCleanupSystem

function HealthRequestCleanupSystem.new(entityFactory: any)
	return setmetatable({
		_entityFactory = entityFactory,
	}, HealthRequestCleanupSystem)
end

function HealthRequestCleanupSystem:Run()
	local processed = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "RequestTag", "ProcessedTag" } })
	if processed.success then
		for _, entity in ipairs(processed.value) do
			if self:_IsHealthRequest(entity) then
				self._entityFactory:MarkEntityForDestruction(entity)
			end
		end
	end

	self:_CleanupExpired("HealthChangeRequest")
	self:_CleanupExpired("HealthDepletedRequest")
	self:_CleanupExpired("HealthDepletedOutcomeRequest")
end

function HealthRequestCleanupSystem:_IsHealthRequest(entity: number): boolean
	return self:_Get(entity, "HealthChangeRequest", "Combat") ~= nil
		or self:_Get(entity, "HealthDepletedRequest", "Combat") ~= nil
		or self:_Get(entity, "HealthDepletedOutcomeRequest", "Combat") ~= nil
end

function HealthRequestCleanupSystem:_CleanupExpired(key: string)
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "RequestTag", key } })
	if not result.success then
		return
	end

	local now = os.clock()
	for _, entity in ipairs(result.value) do
		local request = self:_Get(entity, key, "Combat")
		if type(request) == "table" and type(request.ExpiresAt) == "number" and now >= request.ExpiresAt then
			self._entityFactory:MarkEntityForDestruction(entity)
		end
	end
end

function HealthRequestCleanupSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return HealthRequestCleanupSystem
