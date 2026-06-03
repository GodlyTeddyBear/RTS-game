--!strict

local MovementCleanupOutcomeSystem = {}
MovementCleanupOutcomeSystem.__index = MovementCleanupOutcomeSystem

function MovementCleanupOutcomeSystem.new(entityFactory: any, dependencies: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_pathRuntimeService = dependencies.PathRuntimeService,
		_flowfieldService = dependencies.FlowfieldService,
		_applyBridgeService = dependencies.ApplyBridgeService,
	}, MovementCleanupOutcomeSystem)
end

function MovementCleanupOutcomeSystem:Run()
	-- READS: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupRequestTag
	-- WRITES: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupProcessedTag, Entity.CleanupFailedTag
	local result = self._entityFactory:Query({ FeatureName = "Entity", Keys = { "CleanupOutcomeRequest", "CleanupRequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		local request = self:_Get(requestEntity, "CleanupOutcomeRequest", "Entity")
		if type(request) == "table" and request.OutcomeId == "MovementCleanup" then
			self:_Resolve(requestEntity, request)
		end
	end
end

function MovementCleanupOutcomeSystem:_Resolve(requestEntity: number, request: any)
	local entity = request.SourceEntity
	self._pathRuntimeService:Stop(entity)
	self._flowfieldService:Detach(entity)
	self._applyBridgeService:Invalidate(entity)
	self:_MarkProcessed(requestEntity, request)
end

function MovementCleanupOutcomeSystem:_MarkProcessed(requestEntity: number, request: any)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Processed"
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupProcessedTag", "Entity")
end

function MovementCleanupOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MovementCleanupOutcomeSystem
