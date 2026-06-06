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
		ReplicationServiceStatus = input._replicationService:GetStatus(),
		InstanceBindingServiceStatus = input._instanceBindingService:GetStatus(),
		RuntimeParticipationStatus = input._runtimeParticipation:GetStatus(),
		SchemaReady = input._schemaRegistry:ValidateReady().success,
		SystemReady = input._systemRegistry:ValidateReady().success,
		RuntimeBindingsReady = input._instanceBindingRegistry:ValidateReady().success,
		RuntimeSyncReady = input._syncContributorRegistry:ValidateReady().success,
		RuntimeReplicationReady = input._replicationRegistry:ValidateReady().success,
		SchedulerBound = input._runtimeScheduler:GetStatus().SchedulerBound,
		RuntimeTickActive = input._runtimeScheduler:GetStatus().RuntimeTickActive,
		LastStartupFailure = input._startupState:GetLastStartupFailure(),
		RegistrationBarrierStatus = input._registrationBarrier:GetStatus(),
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
	runtimeParticipationPolicy: any,
	runtimeParticipation: any,
	entity: number
): Result.Result<boolean>
	return runtimeParticipationPolicy:RequireBindingParticipation(runtimeParticipation, entity)
end

return table.freeze(EntityOperationSupport)
