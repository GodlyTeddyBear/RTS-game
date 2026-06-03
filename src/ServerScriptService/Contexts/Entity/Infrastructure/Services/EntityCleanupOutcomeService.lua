--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local CLEANUP_PHASES = table.freeze({
	"CleanupResolve",
})

local EntityCleanupOutcomeService = {}
EntityCleanupOutcomeService.__index = EntityCleanupOutcomeService

function EntityCleanupOutcomeService.new()
	return setmetatable({
		_entityFactory = nil,
		_systemRegistry = nil,
	}, EntityCleanupOutcomeService)
end

function EntityCleanupOutcomeService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EntityEntityFactory")
	self._systemRegistry = registry:Get("EntitySystemRegistry")
end

function EntityCleanupOutcomeService:ResolveEntity(_entityContext: any, entity: number): Result.Result<number>
	return Result.Catch(function()
		if not self._entityFactory:Exists(entity) then
			return Result.Ok(0)
		end

		local cleanupOutcomes = self:_Get(entity, "CleanupOutcomes", "Entity")
		local outcomeIds = if type(cleanupOutcomes) == "table" then cleanupOutcomes.OutcomeIds else nil
		if type(outcomeIds) ~= "table" or #outcomeIds == 0 then
			return Result.Ok(0)
		end

		local requestEntities = {}
		for _, outcomeId in ipairs(outcomeIds) do
			if type(outcomeId) ~= "string" or outcomeId == "" then
				continue
			end

			local requestResult = self:_CreateRequest(entity, outcomeId)
			if not requestResult.success then
				return requestResult
			end
			table.insert(requestEntities, requestResult.value)
		end

		if #requestEntities == 0 then
			return Result.Ok(0)
		end

		local runResult = self._systemRegistry:RunPhases(CLEANUP_PHASES)
		if not runResult.success then
			self:_DeleteRequests(requestEntities)
			return runResult
		end

		local validateResult = self:_ValidateRequests(entity, requestEntities)
		if not validateResult.success then
			self:_DeleteRequests(requestEntities)
			return validateResult
		end

		self:_DeleteRequests(requestEntities)
		self._entityFactory:Set(entity, "CleanupOutcomes", {
			OutcomeIds = {},
		}, "Entity")

		return Result.Ok(#requestEntities)
	end, "EntityCleanupOutcomeService:ResolveEntity")
end

function EntityCleanupOutcomeService:GetStatus(): any
	return table.freeze({
		CleanupPhases = CLEANUP_PHASES,
	})
end

function EntityCleanupOutcomeService:_CreateRequest(sourceEntity: number, outcomeId: string): Result.Result<number>
	local createResult = self._entityFactory:CreateFromArchetype("Entity.CleanupRequest", {
		CleanupOutcomeRequest = {
			SourceEntity = sourceEntity,
			OutcomeId = outcomeId,
			CreatedAt = os.clock(),
			Status = "Requested",
		},
	})
	if not createResult.success then
		return createResult
	end

	return Result.Ok(createResult.value)
end

function EntityCleanupOutcomeService:_ValidateRequests(sourceEntity: number, requestEntities: { number }): Result.Result<boolean>
	for _, requestEntity in ipairs(requestEntities) do
		if not self._entityFactory:Exists(requestEntity) then
			continue
		end

		local request = self:_Get(requestEntity, "CleanupOutcomeRequest", "Entity")
		if type(request) ~= "table" then
			self:_MarkFailed(requestEntity, request, "InvalidRequest")
			return Result.Err("InvalidCleanupOutcome", Errors.INVALID_CLEANUP_OUTCOME, {
				RequestEntity = requestEntity,
				Reason = "InvalidRequest",
			})
		end

		local failed = self:_Has(requestEntity, "CleanupFailedTag", "Entity")
		if failed == true or request.Status == "Failed" then
			return Result.Err("CleanupOutcomeFailed", Errors.CLEANUP_OUTCOME_FAILED, {
				RequestEntity = requestEntity,
				OutcomeId = request.OutcomeId,
				SourceEntity = request.SourceEntity,
				Reason = request.FailureReason,
			})
		end

		local processed = self:_Has(requestEntity, "CleanupProcessedTag", "Entity")
		if processed ~= true or request.Status ~= "Processed" then
			self:_MarkFailed(requestEntity, request, "UnknownOutcome")
			return Result.Err("UnknownCleanupOutcome", Errors.UNKNOWN_CLEANUP_OUTCOME, {
				RequestEntity = requestEntity,
				OutcomeId = request.OutcomeId,
				SourceEntity = sourceEntity,
			})
		end
	end

	return Result.Ok(true)
end

function EntityCleanupOutcomeService:_DeleteRequests(requestEntities: { number })
	for _, requestEntity in ipairs(requestEntities) do
		self._entityFactory:DeleteEntityNow(requestEntity)
	end
end

function EntityCleanupOutcomeService:_MarkFailed(requestEntity: number, request: any, reason: string)
	if type(request) == "table" then
		local nextRequest = table.clone(request)
		nextRequest.Status = "Failed"
		nextRequest.FailureReason = reason
		self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	end
	self._entityFactory:Add(requestEntity, "CleanupFailedTag", "Entity")
end

function EntityCleanupOutcomeService:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

function EntityCleanupOutcomeService:_Has(entity: number, key: string, featureName: string): boolean
	local result = self._entityFactory:Has(entity, featureName, key)
	return result.success and result.value == true
end

return EntityCleanupOutcomeService
