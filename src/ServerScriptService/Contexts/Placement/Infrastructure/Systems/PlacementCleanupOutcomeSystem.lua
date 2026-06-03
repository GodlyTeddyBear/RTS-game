--!strict

local PlacementCleanupOutcomeSystem = {}
PlacementCleanupOutcomeSystem.__index = PlacementCleanupOutcomeSystem

function PlacementCleanupOutcomeSystem.new(entityFactory: any, placementContext: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_placementContext = placementContext,
	}, PlacementCleanupOutcomeSystem)
end

function PlacementCleanupOutcomeSystem:Run()
	-- READS: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupRequestTag, Structure.SourcePlacement [AUTHORITATIVE]
	-- WRITES: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupProcessedTag, Entity.CleanupFailedTag
	local result = self._entityFactory:Query({ FeatureName = "Entity", Keys = { "CleanupOutcomeRequest", "CleanupRequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		local request = self:_Get(requestEntity, "CleanupOutcomeRequest", "Entity")
		if type(request) == "table" and request.OutcomeId == "PlacementDestroy" then
			self:_Resolve(requestEntity, request)
		end
	end
end

function PlacementCleanupOutcomeSystem:_Resolve(requestEntity: number, request: any)
	local placement = self:_Get(request.SourceEntity, "SourcePlacement", "Structure")
	if type(placement) ~= "table" or type(placement.InstanceId) ~= "number" then
		self:_MarkProcessed(requestEntity, request)
		return
	end

	local destroyResult = self._placementContext:DestroyStructureInstance(placement.InstanceId)
	if destroyResult.success then
		self:_MarkProcessed(requestEntity, request)
		return
	end

	self:_MarkFailed(requestEntity, request, destroyResult.message)
end

function PlacementCleanupOutcomeSystem:_MarkProcessed(requestEntity: number, request: any)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Processed"
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupProcessedTag", "Entity")
end

function PlacementCleanupOutcomeSystem:_MarkFailed(requestEntity: number, request: any, reason: string?)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Failed"
	nextRequest.FailureReason = reason
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupFailedTag", "Entity")
end

function PlacementCleanupOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return PlacementCleanupOutcomeSystem
