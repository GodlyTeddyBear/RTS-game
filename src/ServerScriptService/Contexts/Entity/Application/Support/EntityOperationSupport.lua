--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local EntityOperationSupport = {}

function EntityOperationSupport.RequireLifecycleStates(
	_validationService: any,
	methodName: string,
	currentState: string,
	expectedStates: { string }
): Result.Result<boolean>
	for _, expectedState in ipairs(expectedStates) do
		if currentState == expectedState then
			return Result.Ok(true)
		end
	end

	return Result.Err("InvalidEntityLifecycleState", Errors.INVALID_LIFECYCLE_STATE, {
		MethodName = methodName,
		CurrentState = currentState,
		ExpectedStates = table.clone(expectedStates),
	})
end

function EntityOperationSupport.BuildReadinessStatus(input: any): any
	return input._readinessPolicy:BuildStatus({
		LifecycleState = input._lifecycle:GetState(),
		SchemaStatus = input._schemaRegistry:GetStatus(),
		SystemStatus = input._systemRegistry:GetStatus(),
		InstanceBindingRegistryStatus = input._instanceBindingRegistry:GetStatus(),
		SyncContributorRegistryStatus = input._syncContributorRegistry:GetStatus(),
		ReplicationRegistryStatus = input._replicationRegistry:GetStatus(),
		AIActorTypeRegistryStatus = input._aiActorTypeRegistry:GetStatus(),
		AIBridgeStatus = input._combatAIRuntimeBridge:GetStatus(),
		ReplicationServiceStatus = input._replicationService:GetStatus(),
		InstanceBindingServiceStatus = input._instanceBindingService:GetStatus(),
		RuntimeParticipationStatus = input._runtimeParticipation:GetStatus(),
		AIEntityRegistryStatus = input._aiEntityRegistry:GetStatus(),
		SchemaReady = input._schemaRegistry:ValidateReady().success,
		SystemReady = input._systemRegistry:ValidateReady().success,
		RuntimeBindingsReady = input._instanceBindingRegistry:ValidateReady().success,
		RuntimeSyncReady = input._syncContributorRegistry:ValidateReady().success,
		RuntimeReplicationReady = input._replicationRegistry:ValidateReady().success,
		AIActorTypesReady = input._aiActorTypeRegistry:ValidateReady().success,
		AIBridgeReady = input._combatAIRuntimeBridge:ValidateReady().success,
		SchedulerBound = input._runtimeScheduler:GetStatus().SchedulerBound,
		RuntimeTickActive = input._runtimeScheduler:GetStatus().RuntimeTickActive,
		LastStartupFailure = input._startupState:GetLastStartupFailure(),
	})
end

function EntityOperationSupport.OnRuntimeEntityBound(
	entityContext: any,
	runtimeParticipation: any,
	replicationService: any,
	entity: number
): Result.Result<boolean>
	local featureName = runtimeParticipation:GetFeatureName(entity)
	if featureName == nil then
		return Result.Ok(false)
	end

	if runtimeParticipation:IsFeatureEnabled("Replication", featureName) then
		return replicationService:RegisterRuntimeEntity(entityContext, entity)
	end

	return Result.Ok(true)
end

function EntityOperationSupport.PrepareRuntimeEntityForRemoval(input: any, entity: number, unregisterRuntimeEntity: boolean)
	return Result.Catch(function()
		input._instanceBindingService:ClearQueuedBind(entity)

		local runtimeFeatureName = input._runtimeParticipation:GetFeatureName(entity)
		if runtimeFeatureName ~= nil and input._runtimeParticipation:IsFeatureEnabled("Replication", runtimeFeatureName) then
			local unregisterReplicationResult = input._replicationService:UnregisterRuntimeEntity(input._entityContext, entity)
			if not unregisterReplicationResult.success then
				return unregisterReplicationResult
			end
		end

		local unbindResult = input._instanceBindingService:UnbindEntityInstance(entity)
		if not unbindResult.success then
			return unbindResult
		end

		local aiRegistration = input._aiEntityRegistry:GetAIRegistration(entity)
		if aiRegistration ~= nil then
			local unregisterAIResult = input._unregisterAIEntityCommand:Execute(entity)
			if not unregisterAIResult.success then
				return unregisterAIResult
			end
		end

		if unregisterRuntimeEntity then
			local unregisterRuntimeResult = input._runtimeParticipation:UnregisterRuntimeEntity(entity)
			if not unregisterRuntimeResult.success then
				return unregisterRuntimeResult
			end
		end

		return Result.Ok(true)
	end, "EntityOperationSupport:PrepareRuntimeEntityForRemoval")
end

function EntityOperationSupport.ShutdownRuntimeExecution(input: any)
	for _, entity in ipairs(input._aiEntityRegistry:CollectRegisteredEntities()) do
		input._unregisterAIEntityCommand:Execute(entity)
	end

	for _, entity in ipairs(input._runtimeParticipation:CollectRuntimeEntities()) do
		EntityOperationSupport.PrepareRuntimeEntityForRemoval(input, entity, true)
	end

	input._instanceBindingService:DestroyAll()
end

function EntityOperationSupport.FlushPendingDestructionDuringShutdown(entityFactory: any)
	local flushResult = entityFactory:FlushDestroyQueue()
	if flushResult.success then
		return
	end

	Result.MentionError("Entity:Shutdown", "Failed to flush destruction queue during shutdown", {
		CauseType = flushResult.type,
		CauseMessage = flushResult.message,
		Details = flushResult.data,
	}, flushResult.type)
end

function EntityOperationSupport.RequireRuntimeBindingParticipation(
	runtimeParticipation: any,
	entity: number
): Result.Result<boolean>
	local featureName = runtimeParticipation:GetFeatureName(entity)
	if featureName == nil then
		return Result.Err("UnknownRuntimeEntity", Errors.UNKNOWN_RUNTIME_ENTITY, {
			Entity = entity,
		})
	end

	if not runtimeParticipation:IsFeatureEnabled("Binding", featureName) then
		return Result.Err("FeatureRuntimeNotEnabled", Errors.FEATURE_RUNTIME_NOT_ENABLED, {
			Entity = entity,
			FeatureName = featureName,
			Mode = "Binding",
		})
	end

	return Result.Ok(true)
end

return table.freeze(EntityOperationSupport)
