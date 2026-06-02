--!strict

local StructureHealthDepletedSystem = {}
StructureHealthDepletedSystem.__index = StructureHealthDepletedSystem

function StructureHealthDepletedSystem.new(entityFactory: any, entityContext: any)
	return setmetatable({ _entityFactory = entityFactory, _entityContext = entityContext }, StructureHealthDepletedSystem)
end

function StructureHealthDepletedSystem:Run()
	-- READS: Combat.HealthDepletedRequest [AUTHORITATIVE]
	-- WRITES: Combat.ProcessedTag, Entity.DestructionQueue
	local result = self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthDepletedRequest", "RequestTag" } })
	if not result.success then return end
	for _, requestEntity in ipairs(result.value) do
		local request = self:_Get(requestEntity, "HealthDepletedRequest", "Combat")
		if type(request) == "table" and request.VictimKind == "Structure" and type(request.VictimEntity) == "number" then
			self._entityContext:MarkForDestruction(request.VictimEntity)
			self._entityFactory:Add(requestEntity, "ProcessedTag", "Combat")
		end
	end
end

function StructureHealthDepletedSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return StructureHealthDepletedSystem
