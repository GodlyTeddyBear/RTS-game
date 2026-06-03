--!strict

local MiningEntityReadService = {}
MiningEntityReadService.__index = MiningEntityReadService

function MiningEntityReadService.new()
	local self = setmetatable({}, MiningEntityReadService)
	self._entityContext = nil
	self._extractorEntitiesByInstanceId = {} :: { [number]: number }
	self._resourceNodeEntitiesByInstance = {} :: { [BasePart]: number }
	self._resourceNodeInstancesByEntity = {} :: { [number]: BasePart }
	return self
end

function MiningEntityReadService:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
end

function MiningEntityReadService:RegisterExtractorInstance(instanceId: number, entity: number)
	self._extractorEntitiesByInstanceId[instanceId] = entity
end

function MiningEntityReadService:GetExtractorEntityByInstanceId(instanceId: number): number?
	local cached = self._extractorEntitiesByInstanceId[instanceId]
	if cached ~= nil then
		return cached
	end

	for _, entity in ipairs(self:QueryActiveExtractors()) do
		local extractor = self:GetExtractor(entity)
		if type(extractor) == "table" and extractor.InstanceId == instanceId then
			self._extractorEntitiesByInstanceId[instanceId] = entity
			return entity
		end
	end

	return nil
end

function MiningEntityReadService:RegisterResourceNodeInstance(entity: number, resourcePart: BasePart)
	self._resourceNodeEntitiesByInstance[resourcePart] = entity
	self._resourceNodeInstancesByEntity[entity] = resourcePart
end

function MiningEntityReadService:GetResourceNodeEntityForPart(resourcePart: BasePart): number?
	return self._resourceNodeEntitiesByInstance[resourcePart]
end

function MiningEntityReadService:GetResourceNodeInstance(entity: number): BasePart?
	return self._resourceNodeInstancesByEntity[entity]
end

function MiningEntityReadService:QueryActiveExtractors(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Mining",
		Keys = { "Extractor", "ExtractorActiveTag" },
	})
	return if queryResult.success then queryResult.value else {}
end

function MiningEntityReadService:QueryResourceNodes(): { number }
	local queryResult = self._entityContext:Query({
		FeatureName = "Mining",
		Keys = { "ResourceNode", "ResourceNodeTag" },
	})
	return if queryResult.success then queryResult.value else {}
end

function MiningEntityReadService:GetExtractor(entity: number): any?
	local result = self._entityContext:Get(entity, "Extractor", "Mining")
	return if result.success then result.value else nil
end

function MiningEntityReadService:GetExtractorTiming(entity: number): any?
	local result = self._entityContext:Get(entity, "ExtractorTiming", "Mining")
	return if result.success then result.value else nil
end

function MiningEntityReadService:GetResourceNode(entity: number): any?
	local result = self._entityContext:Get(entity, "ResourceNode", "Mining")
	return if result.success then result.value else nil
end

function MiningEntityReadService:Clear()
	table.clear(self._extractorEntitiesByInstanceId)
	table.clear(self._resourceNodeEntitiesByInstance)
	table.clear(self._resourceNodeInstancesByEntity)
end

return MiningEntityReadService
