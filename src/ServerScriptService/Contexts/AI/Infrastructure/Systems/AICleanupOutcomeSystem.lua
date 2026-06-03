--!strict

local AICleanupOutcomeSystem = {}
AICleanupOutcomeSystem.__index = AICleanupOutcomeSystem

function AICleanupOutcomeSystem.new(entityFactory: any, cleanupCommand: any)
	return setmetatable({
		_entityFactory = entityFactory,
		_cleanupCommand = cleanupCommand,
	}, AICleanupOutcomeSystem)
end

function AICleanupOutcomeSystem:Run()
	-- READS: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupRequestTag
	-- WRITES: Entity.CleanupOutcomeRequest [AUTHORITATIVE], Entity.CleanupProcessedTag, Entity.CleanupFailedTag
	local result = self._entityFactory:Query({ FeatureName = "Entity", Keys = { "CleanupOutcomeRequest", "CleanupRequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		local request = self:_Get(requestEntity, "CleanupOutcomeRequest", "Entity")
		if type(request) == "table" and request.OutcomeId == "AICleanup" then
			self:_Resolve(requestEntity, request)
		end
	end
end

function AICleanupOutcomeSystem:_Resolve(requestEntity: number, request: any)
	local cleanupResult = self._cleanupCommand:Execute(request.SourceEntity)
	if cleanupResult.success then
		self:_MarkProcessed(requestEntity, request)
		return
	end

	self:_MarkFailed(requestEntity, request, cleanupResult.message)
end

function AICleanupOutcomeSystem:_MarkProcessed(requestEntity: number, request: any)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Processed"
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupProcessedTag", "Entity")
end

function AICleanupOutcomeSystem:_MarkFailed(requestEntity: number, request: any, reason: string?)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Failed"
	nextRequest.FailureReason = reason
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupFailedTag", "Entity")
end

function AICleanupOutcomeSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return AICleanupOutcomeSystem
