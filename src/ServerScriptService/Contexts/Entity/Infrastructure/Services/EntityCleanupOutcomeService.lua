--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

export type TCleanupOutcomePayload = {
	OutcomeId: string,
	Handle: (context: any) -> any,
}

local EntityCleanupOutcomeService = {}
EntityCleanupOutcomeService.__index = EntityCleanupOutcomeService

function EntityCleanupOutcomeService.new()
	return setmetatable({
		_entityFactory = nil,
		_handlersById = {},
	}, EntityCleanupOutcomeService)
end

function EntityCleanupOutcomeService:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("EntityEntityFactory")
end

function EntityCleanupOutcomeService:RegisterHandler(payload: TCleanupOutcomePayload): Result.Result<boolean>
	return Result.Catch(function()
		local validationResult = self:_ValidatePayload(payload)
		if not validationResult.success then
			return validationResult
		end

		self._handlersById[payload.OutcomeId] = table.freeze({
			OutcomeId = payload.OutcomeId,
			Handle = payload.Handle,
		})

		return Result.Ok(true)
	end, "EntityCleanupOutcomeService:RegisterHandler")
end

function EntityCleanupOutcomeService:ResolveEntity(entityContext: any, entity: number): Result.Result<number>
	return Result.Catch(function()
		if not self._entityFactory:Exists(entity) then
			return Result.Ok(0)
		end

		local cleanupOutcomes = self:_Get(entity, "CleanupOutcomes", "Entity")
		local outcomeIds = if type(cleanupOutcomes) == "table" then cleanupOutcomes.OutcomeIds else nil
		if type(outcomeIds) ~= "table" or #outcomeIds == 0 then
			return Result.Ok(0)
		end

		local resolvedCount = 0
		for _, outcomeId in ipairs(outcomeIds) do
			if type(outcomeId) ~= "string" or outcomeId == "" then
				continue
			end

			local requestResult = self:_CreateRequest(entity, outcomeId)
			if not requestResult.success then
				return requestResult
			end
			local requestEntity = requestResult.value
			local resolveResult = self:_ResolveRequest(entityContext, requestEntity)
			if not resolveResult.success then
				return resolveResult
			end
			resolvedCount += 1
		end

		if resolvedCount > 0 then
			self._entityFactory:Set(entity, "CleanupOutcomes", {
				OutcomeIds = {},
			}, "Entity")
		end

		return Result.Ok(resolvedCount)
	end, "EntityCleanupOutcomeService:ResolveEntity")
end

function EntityCleanupOutcomeService:GetStatus(): any
	local handlerCount = 0
	for _ in pairs(self._handlersById) do
		handlerCount += 1
	end

	return table.freeze({
		HandlerCount = handlerCount,
	})
end

function EntityCleanupOutcomeService:_ValidatePayload(payload: TCleanupOutcomePayload): Result.Result<boolean>
	if type(payload) ~= "table" or type(payload.OutcomeId) ~= "string" or payload.OutcomeId == "" then
		return Result.Err("InvalidCleanupOutcome", Errors.INVALID_CLEANUP_OUTCOME, {
			Reason = "MissingOutcomeId",
		})
	end
	if type(payload.Handle) ~= "function" then
		return Result.Err("InvalidCleanupOutcome", Errors.INVALID_CLEANUP_OUTCOME, {
			OutcomeId = payload.OutcomeId,
			Reason = "MissingHandler",
		})
	end
	if self._handlersById[payload.OutcomeId] ~= nil then
		return Result.Err("DuplicateCleanupOutcome", Errors.DUPLICATE_CLEANUP_OUTCOME, {
			OutcomeId = payload.OutcomeId,
		})
	end

	return Result.Ok(true)
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

function EntityCleanupOutcomeService:_ResolveRequest(entityContext: any, requestEntity: number): Result.Result<boolean>
	local request = self:_Get(requestEntity, "CleanupOutcomeRequest", "Entity")
	if type(request) ~= "table" or type(request.OutcomeId) ~= "string" or request.OutcomeId == "" then
		self:_MarkFailedAndDelete(requestEntity, request, "InvalidRequest")
		return Result.Err("InvalidCleanupOutcome", Errors.INVALID_CLEANUP_OUTCOME, {
			RequestEntity = requestEntity,
			Reason = "InvalidRequest",
		})
	end

	local handler = self._handlersById[request.OutcomeId]
	if handler == nil then
		self:_MarkFailedAndDelete(requestEntity, request, "UnknownOutcome")
		return Result.Err("UnknownCleanupOutcome", Errors.UNKNOWN_CLEANUP_OUTCOME, {
			RequestEntity = requestEntity,
			OutcomeId = request.OutcomeId,
			SourceEntity = request.SourceEntity,
		})
	end

	local didRun, handlerResult = pcall(handler.Handle, {
		RequestEntity = requestEntity,
		Request = request,
		EntityContext = entityContext,
		EntityFactory = self._entityFactory,
	})
	if not didRun then
		self:_MarkFailedAndDelete(requestEntity, request, tostring(handlerResult))
		return Result.Err("CleanupOutcomeFailed", Errors.CLEANUP_OUTCOME_FAILED, {
			RequestEntity = requestEntity,
			OutcomeId = request.OutcomeId,
			SourceEntity = request.SourceEntity,
			Reason = tostring(handlerResult),
		})
	end

	if Result.isResult(handlerResult) and not handlerResult.success then
		self:_MarkFailedAndDelete(requestEntity, request, handlerResult.message)
		return Result.Err("CleanupOutcomeFailed", Errors.CLEANUP_OUTCOME_FAILED, {
			RequestEntity = requestEntity,
			OutcomeId = request.OutcomeId,
			SourceEntity = request.SourceEntity,
			CauseType = handlerResult.type,
			CauseMessage = handlerResult.message,
			Details = handlerResult.data,
		})
	end

	if handlerResult == false then
		self:_MarkFailedAndDelete(requestEntity, request, "HandlerReturnedFalse")
		return Result.Err("CleanupOutcomeFailed", Errors.CLEANUP_OUTCOME_FAILED, {
			RequestEntity = requestEntity,
			OutcomeId = request.OutcomeId,
			SourceEntity = request.SourceEntity,
			Reason = "HandlerReturnedFalse",
		})
	end

	self:_MarkProcessedAndDelete(requestEntity, request)
	return Result.Ok(true)
end

function EntityCleanupOutcomeService:_MarkProcessedAndDelete(requestEntity: number, request: any)
	local nextRequest = table.clone(request)
	nextRequest.Status = "Processed"
	self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	self._entityFactory:Add(requestEntity, "CleanupProcessedTag", "Entity")
	self._entityFactory:DeleteEntityNow(requestEntity)
end

function EntityCleanupOutcomeService:_MarkFailedAndDelete(requestEntity: number, request: any, reason: string?)
	if type(request) == "table" then
		local nextRequest = table.clone(request)
		nextRequest.Status = "Failed"
		nextRequest.FailureReason = reason
		self._entityFactory:Set(requestEntity, "CleanupOutcomeRequest", nextRequest, "Entity")
	end
	self._entityFactory:Add(requestEntity, "CleanupFailedTag", "Entity")
	self._entityFactory:DeleteEntityNow(requestEntity)
end

function EntityCleanupOutcomeService:_Get(entity: number, key: string, featureName: string): any
	local result = self._entityFactory:Get(entity, key, featureName)
	return if result.success then result.value else nil
end

return EntityCleanupOutcomeService
