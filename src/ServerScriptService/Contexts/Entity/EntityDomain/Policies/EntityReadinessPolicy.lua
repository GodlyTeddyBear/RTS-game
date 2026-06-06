--!strict

local EntityReadinessPolicy = {}
EntityReadinessPolicy.__index = EntityReadinessPolicy

function EntityReadinessPolicy.new()
	return setmetatable({}, EntityReadinessPolicy)
end

function EntityReadinessPolicy:Init(_registry: any, _name: string)
	return
end

function EntityReadinessPolicy:BuildStatus(input: any): any
	local status = {
		LifecycleState = input.LifecycleState,
		Registration = input.RegistrationBarrierStatus,
		ECS = {
			RegistrationClosed = input.SchemaStatus.RegistrationClosed,
			CompileStarted = input.SchemaStatus.CompileStarted,
			Compiled = input.SchemaStatus.Compiled,
			CoreSchemaRegistered = input.SchemaStatus.CoreSchemaRegistered,
			SystemsClosed = input.SystemStatus.RegistrationClosed,
			Ready = input.SchemaReady and input.SystemReady,
			FeatureSchemaCount = input.SchemaStatus.FeatureSchemaCount,
			ArchetypeCount = input.SchemaStatus.ArchetypeCount,
			RegisteredSystemCount = input.SystemStatus.RegisteredSystemCount,
		},
		Runtime = {
			BindingsClosed = input.InstanceBindingRegistryStatus.RegistrationClosed,
			SyncClosed = input.SyncContributorRegistryStatus.RegistrationClosed,
			ReplicationClosed = input.ReplicationRegistryStatus.RegistrationClosed,
			Ready = input.RuntimeBindingsReady
				and input.RuntimeSyncReady
				and input.RuntimeReplicationReady
				and input.ReplicationServiceStatus.BootCapable,
			BindingCount = input.InstanceBindingRegistryStatus.BindingCount,
			SyncContributorCount = input.SyncContributorRegistryStatus.ContributorCount,
			ReplicationSurfaceCount = input.ReplicationRegistryStatus.SurfaceCount,
			RuntimeEntityCount = input.RuntimeParticipationStatus.RuntimeEntityCount,
			EnabledFeatures = input.RuntimeParticipationStatus.EnabledFeatures,
			BoundEntityCount = input.InstanceBindingServiceStatus.BoundEntityCount,
			PendingBindCount = input.InstanceBindingServiceStatus.PendingBindCount,
		},
		Execution = {
			SchedulerBound = input.SchedulerBound,
			RuntimeTickActive = input.RuntimeTickActive and input.LifecycleState == "Running",
			ShutdownStarted = input.LifecycleState == "ShuttingDown" or input.LifecycleState == "Destroyed",
			Destroyed = input.LifecycleState == "Destroyed",
			ReplicationBootCapable = input.ReplicationServiceStatus.BootCapable,
			HasAppliedReplicationSchema = input.ReplicationServiceStatus.HasAppliedSharedSchema,
			LastStartupFailure = input.LastStartupFailure,
		},
	}

	status.Acceptance = self:BuildAcceptance(status)
	return table.freeze(status)
end

function EntityReadinessPolicy:BuildAcceptance(status: any): any
	local blockingGaps = {}

	local function addBlockingGap(code: string, message: string, details: any?)
		table.insert(blockingGaps, {
			Code = code,
			Message = message,
			Details = details,
		})
	end

	if status.LifecycleState ~= "Running" then
		addBlockingGap("LifecycleNotRunning", "EntityContext is not in the Running lifecycle state", {
			LifecycleState = status.LifecycleState,
		})
	end
	if #status.Registration.Pending > 0 then
		addBlockingGap("RegistrationParticipantsPending", "Entity registration participants are still pending", {
			Participants = status.Registration.Pending,
		})
	end
	if next(status.Registration.Failed) ~= nil then
		addBlockingGap("RegistrationParticipantFailed", "An Entity registration participant failed", {
			Participants = status.Registration.Failed,
		})
	end

	if not status.ECS.CoreSchemaRegistered then
		addBlockingGap("MissingCoreSchema", "EntityContext core schema is not registered")
	end
	if not status.ECS.Compiled then
		addBlockingGap("ECSNotCompiled", "EntityContext ECS kernel has not been finalized")
	end
	if not status.ECS.SystemsClosed then
		addBlockingGap("SystemRegistrationOpen", "Entity system registration is still open")
	end
	if not status.ECS.Ready then
		addBlockingGap("ECSNotReady", "Entity ECS validation has not passed")
	end

	if not status.Runtime.BindingsClosed then
		addBlockingGap("BindingRegistrationOpen", "Entity instance binding registration is still open")
	end
	if not status.Runtime.SyncClosed then
		addBlockingGap("SyncRegistrationOpen", "Entity sync contributor registration is still open")
	end
	if not status.Runtime.ReplicationClosed then
		addBlockingGap("ReplicationRegistrationOpen", "Entity replication surface registration is still open")
	end
	if not status.Runtime.Ready then
		addBlockingGap("RuntimeNotReady", "Entity runtime bridge validation has not passed")
	end

	if not status.Execution.SchedulerBound then
		addBlockingGap("SchedulerNotBound", "Entity scheduler tick has not been bound")
	end
	if not status.Execution.ReplicationBootCapable then
		addBlockingGap("ReplicationNotBootCapable", "Entity replication shell is not boot-capable")
	end
	if status.Execution.ShutdownStarted then
		addBlockingGap("ShutdownStarted", "EntityContext shutdown has already started")
	end
	if status.Execution.LastStartupFailure ~= nil then
		addBlockingGap("StartupFailureRecorded", "EntityContext recorded a startup failure", status.Execution.LastStartupFailure)
	end

	if status.LifecycleState == "ShuttingDown" or status.LifecycleState == "Destroyed" then
		if status.Runtime.PendingBindCount > 0 then
			addBlockingGap("PendingBindCleanup", "EntityContext still has queued runtime binds", {
				PendingBindCount = status.Runtime.PendingBindCount,
			})
		end
		if status.Runtime.BoundEntityCount > 0 then
			addBlockingGap("BoundInstanceCleanup", "EntityContext still has bound runtime instances", {
				BoundEntityCount = status.Runtime.BoundEntityCount,
			})
		end
		if status.Runtime.RuntimeEntityCount > 0 then
			addBlockingGap("RuntimeEntityCleanup", "EntityContext still has runtime-participating entities", {
				RuntimeEntityCount = status.Runtime.RuntimeEntityCount,
			})
		end
	end

	return table.freeze({
		IsReadyForUse = #blockingGaps == 0,
		BlockingGaps = table.freeze(blockingGaps),
	})
end

return EntityReadinessPolicy
