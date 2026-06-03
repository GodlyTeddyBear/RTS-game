--!strict

local MiningExtractWorkRequestSystem = {}
MiningExtractWorkRequestSystem.__index = MiningExtractWorkRequestSystem

function MiningExtractWorkRequestSystem.new(entityFactory: any, dependencies: any)
	local self = setmetatable({}, MiningExtractWorkRequestSystem)
	self._entityFactory = entityFactory
	self._miningContext = dependencies.MiningContext
	return self
end

function MiningExtractWorkRequestSystem:Run()
	-- READS: Mining.ExtractWorkRequest [AUTHORITATIVE], Mining.RequestTag
	-- WRITES: Mining.ExtractWorkRequest [AUTHORITATIVE], Mining.ProcessedTag, Mining.FailedTag, Entity.DestructionQueue
	local result = self._entityFactory:Query({ FeatureName = "Mining", Keys = { "ExtractWorkRequest", "RequestTag" } })
	if not result.success then
		return
	end

	for _, requestEntity in ipairs(result.value) do
		self:_Resolve(requestEntity)
	end
end

function MiningExtractWorkRequestSystem:_Resolve(requestEntity: number)
	local request = self:_Get(requestEntity, "ExtractWorkRequest", "Mining")
	if type(request) ~= "table" or type(request.InstanceId) ~= "number" or type(request.DeltaTime) ~= "number" then
		self:_Fail(requestEntity, "InvalidExtractWorkRequest")
		return
	end

	local applyResult = self._miningContext:ApplyExtractWorkByInstanceId(request.InstanceId, request.DeltaTime)
	if not applyResult.success then
		self:_Fail(requestEntity, tostring(applyResult.type))
		return
	end
	self._entityFactory:Set(requestEntity, "ExtractWorkRequest", {
		SourceEntity = request.SourceEntity,
		InstanceId = request.InstanceId,
		DeltaTime = request.DeltaTime,
		CreatedAt = request.CreatedAt,
		Status = "Processed",
		FailureReason = nil,
	}, "Mining")
	self._entityFactory:Add(requestEntity, "ProcessedTag", "Mining")
	self._entityFactory:MarkEntityForDestruction(requestEntity)
end

function MiningExtractWorkRequestSystem:_Fail(requestEntity: number, reason: string)
	local request = self:_Get(requestEntity, "ExtractWorkRequest", "Mining")
	if type(request) == "table" then
		local nextRequest = table.clone(request)
		nextRequest.Status = "Failed"
		nextRequest.FailureReason = reason
		self._entityFactory:Set(requestEntity, "ExtractWorkRequest", nextRequest, "Mining")
	end
	self._entityFactory:Add(requestEntity, "FailedTag", "Mining")
	self._entityFactory:MarkEntityForDestruction(requestEntity)
end

function MiningExtractWorkRequestSystem:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return MiningExtractWorkRequestSystem
