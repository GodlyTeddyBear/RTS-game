--!strict

local StructureHealthDepletedOutcomeSystem = {}
StructureHealthDepletedOutcomeSystem.__index = StructureHealthDepletedOutcomeSystem

function StructureHealthDepletedOutcomeSystem.new(entityFactory: any)
	return setmetatable({ _entityFactory = entityFactory }, StructureHealthDepletedOutcomeSystem)
end

function StructureHealthDepletedOutcomeSystem:Run()
	-- READS: Combat.HealthDepletedOutcomeRequest, Combat.RequestTag
	-- WRITES: Combat.ProcessedTag, Entity.DestructionQueue
	local result =
		self._entityFactory:Query({ FeatureName = "Combat", Keys = { "HealthDepletedOutcomeRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function StructureHealthDepletedOutcomeSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "HealthDepletedOutcomeRequest", "Combat")
	if type(request) ~= "table" or request.OutcomeId ~= "StructureDeath" then
		return
	end

	if type(request.VictimEntity) == "number" and self._entityFactory:Exists(request.VictimEntity) then
		self._entityFactory:MarkEntityForDestruction(request.VictimEntity)
	end
	self:_Processed(requestEntity)
end

function StructureHealthDepletedOutcomeSystem:_Processed(entity: number)
	self._entityFactory:Add(entity, "ProcessedTag", "Combat")
end

function StructureHealthDepletedOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return StructureHealthDepletedOutcomeSystem
