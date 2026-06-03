--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local EntityLifecycleStateMachine = require(script.Parent.Infrastructure.Services.EntityLifecycleStateMachine)
local EntityStartupStateService = require(script.Parent.Infrastructure.Services.EntityStartupStateService)
local EntityRuntimeSchedulerService = require(script.Parent.Infrastructure.Services.EntityRuntimeSchedulerService)
local EntityRevealService = require(script.Parent.Infrastructure.Services.EntityRevealService)
local EntityECSWorldService = require(script.Parent.Infrastructure.ECS.EntityECSWorldService)
local EntityEntityFactory = require(script.Parent.Infrastructure.ECS.EntityEntityFactory)
local EntityInstanceBindingRegistry = require(script.Parent.Infrastructure.ECS.EntityInstanceBindingRegistry)
local EntityInstanceBindingService = require(script.Parent.Infrastructure.ECS.EntityInstanceBindingService)
local EntitySchemaRegistry = require(script.Parent.Infrastructure.ECS.EntitySchemaRegistry)
local EntitySystemRegistry = require(script.Parent.Infrastructure.ECS.EntitySystemRegistry)
local EntityReplicationRegistry = require(script.Parent.Infrastructure.Persistence.EntityReplicationRegistry)
local EntityReplicationService = require(script.Parent.Infrastructure.Persistence.EntityReplicationService)
local EntityRuntimeSyncService = require(script.Parent.Infrastructure.Persistence.EntityRuntimeSyncService)
local EntitySyncContributorRegistry = require(script.Parent.Infrastructure.Persistence.EntitySyncContributorRegistry)
local EntityRuntimeParticipationService =
	require(script.Parent.Infrastructure.Services.EntityRuntimeParticipationService)
local EntityRuntimeSnapshotBuilder = require(script.Parent.Infrastructure.Services.EntityRuntimeSnapshotBuilder)
local EntityCleanupOutcomeService = require(script.Parent.Infrastructure.Services.EntityCleanupOutcomeService)

local EntityValidationService = require(script.Parent.EntityDomain.Services.EntityValidationService)
local EntityLifecyclePolicy = require(script.Parent.EntityDomain.Policies.EntityLifecyclePolicy)
local EntityReadinessPolicy = require(script.Parent.EntityDomain.Policies.EntityReadinessPolicy)
local EntityRuntimeParticipationPolicy = require(script.Parent.EntityDomain.Policies.EntityRuntimeParticipationPolicy)

local InitCommand = require(script.Parent.Application.Commands.InitCommand)
local StartCommand = require(script.Parent.Application.Commands.StartCommand)
local FinalizeStartupCommand = require(script.Parent.Application.Commands.FinalizeStartupCommand)
local CompileECSKernelCommand = require(script.Parent.Application.Commands.CompileECSKernelCommand)
local FinalizeRuntimeRegistrationCommand = require(script.Parent.Application.Commands.FinalizeRuntimeRegistrationCommand)
local HandleStartupFailureCommand = require(script.Parent.Application.Commands.HandleStartupFailureCommand)
local PrepareRuntimeEntityForRemovalCommand =
	require(script.Parent.Application.Commands.PrepareRuntimeEntityForRemovalCommand)
local ShutdownRuntimeExecutionCommand = require(script.Parent.Application.Commands.ShutdownRuntimeExecutionCommand)
local DestroyCommand = require(script.Parent.Application.Commands.DestroyCommand)
local RunOperationalProofCommand = require(script.Parent.Application.Commands.RunOperationalProofCommand)
local RegisterFeatureSchemaCommand = require(script.Parent.Application.Commands.RegisterFeatureSchemaCommand)
local RegisterEntityFeatureCommand = require(script.Parent.Application.Commands.RegisterEntityFeatureCommand)
local RegisterSystemCommand = require(script.Parent.Application.Commands.RegisterSystemCommand)
local CreateEntityCommand = require(script.Parent.Application.Commands.CreateEntityCommand)
local DestroyEntityCommand = require(script.Parent.Application.Commands.DestroyEntityCommand)
local MarkForDestructionCommand = require(script.Parent.Application.Commands.MarkForDestructionCommand)
local FlushDestructionQueueCommand = require(script.Parent.Application.Commands.FlushDestructionQueueCommand)
local SetCommand = require(script.Parent.Application.Commands.SetCommand)
local AddCommand = require(script.Parent.Application.Commands.AddCommand)
local RemoveCommand = require(script.Parent.Application.Commands.RemoveCommand)
local TickPhaseCommand = require(script.Parent.Application.Commands.TickPhaseCommand)
local TickAllCommand = require(script.Parent.Application.Commands.TickAllCommand)
local RegisterInstanceBindingCommand = require(script.Parent.Application.Commands.RegisterInstanceBindingCommand)
local EnableRuntimeBindingCommand = require(script.Parent.Application.Commands.EnableRuntimeBindingCommand)
local EnableRuntimeSyncCommand = require(script.Parent.Application.Commands.EnableRuntimeSyncCommand)
local EnableRuntimeReplicationCommand = require(script.Parent.Application.Commands.EnableRuntimeReplicationCommand)
local RegisterRuntimeEntityCommand = require(script.Parent.Application.Commands.RegisterRuntimeEntityCommand)
local UnregisterRuntimeEntityCommand = require(script.Parent.Application.Commands.UnregisterRuntimeEntityCommand)
local BindEntityInstanceCommand = require(script.Parent.Application.Commands.BindEntityInstanceCommand)
local UnbindEntityInstanceCommand = require(script.Parent.Application.Commands.UnbindEntityInstanceCommand)
local QueueEntityBindCommand = require(script.Parent.Application.Commands.QueueEntityBindCommand)
local FlushBindQueueCommand = require(script.Parent.Application.Commands.FlushBindQueueCommand)
local RegisterSyncContributorCommand = require(script.Parent.Application.Commands.RegisterSyncContributorCommand)
local RegisterReplicationSurfaceCommand = require(script.Parent.Application.Commands.RegisterReplicationSurfaceCommand)
local RunRuntimeSyncCommand = require(script.Parent.Application.Commands.RunRuntimeSyncCommand)
local RunRuntimePollCommand = require(script.Parent.Application.Commands.RunRuntimePollCommand)
local HydrateEntityReplicationCommand = require(script.Parent.Application.Commands.HydrateEntityReplicationCommand)
local CompleteEntityReplicationBootstrapCommand =
	require(script.Parent.Application.Commands.CompleteEntityReplicationBootstrapCommand)
local FlushEntityReplicationReliableCommand =
	require(script.Parent.Application.Commands.FlushEntityReplicationReliableCommand)
local FlushEntityReplicationUnreliableCommand =
	require(script.Parent.Application.Commands.FlushEntityReplicationUnreliableCommand)
local FlushEntityReplicationEntityCommand =
	require(script.Parent.Application.Commands.FlushEntityReplicationEntityCommand)

local GetLifecycleStateQuery = require(script.Parent.Application.Queries.GetLifecycleStateQuery)
local GetReadinessStatusQuery = require(script.Parent.Application.Queries.GetReadinessStatusQuery)
local GetRegistrationStatusQuery = require(script.Parent.Application.Queries.GetRegistrationStatusQuery)
local RunAcceptanceCheckQuery = require(script.Parent.Application.Queries.RunAcceptanceCheckQuery)
local GetEntityValueQuery = require(script.Parent.Application.Queries.GetEntityValueQuery)
local HasEntityKeyQuery = require(script.Parent.Application.Queries.HasEntityKeyQuery)
local QueryEntitiesQuery = require(script.Parent.Application.Queries.QueryEntitiesQuery)
local GetWorldQuery = require(script.Parent.Application.Queries.GetWorldQuery)
local GetFeatureComponentsQuery = require(script.Parent.Application.Queries.GetFeatureComponentsQuery)
local GetEntityFactoryQuery = require(script.Parent.Application.Queries.GetEntityFactoryQuery)
local GetBoundInstanceQuery = require(script.Parent.Application.Queries.GetBoundInstanceQuery)
local GetBoundEntityQuery = require(script.Parent.Application.Queries.GetBoundEntityQuery)
local BuildRuntimeSnapshotQuery = require(script.Parent.Application.Queries.BuildRuntimeSnapshotQuery)
local GetSyncContributorQuery = require(script.Parent.Application.Queries.GetSyncContributorQuery)
local GetReplicationSurfaceQuery = require(script.Parent.Application.Queries.GetReplicationSurfaceQuery)

local Catch = Result.Catch

local function moduleSpec(name: string, module: any, cacheAs: string): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ClientSignals",
		Factory = function(service: any, _baseContext: any)
			return service.Client
		end,
	},
	{
		Name = "EntityContextService",
		Factory = function(service: any, _baseContext: any)
			return service
		end,
	},
	{
		Name = "EntityBaseContext",
		Factory = function(_service: any, baseContext: any)
			return baseContext
		end,
	},
	moduleSpec("EntityLifecycleStateMachine", EntityLifecycleStateMachine, "_lifecycle"),
	moduleSpec("EntityStartupStateService", EntityStartupStateService, "_startupState"),
	moduleSpec("EntitySchemaRegistry", EntitySchemaRegistry, "_schemaRegistry"),
	moduleSpec("EntityEntityFactory", EntityEntityFactory, "_entityFactory"),
	moduleSpec("EntityInstanceBindingRegistry", EntityInstanceBindingRegistry, "_instanceBindingRegistry"),
	moduleSpec("EntityRevealService", EntityRevealService, "_revealService"),
	moduleSpec("EntityRuntimeSnapshotBuilder", EntityRuntimeSnapshotBuilder, "_runtimeSnapshotBuilder"),
	moduleSpec("EntityCleanupOutcomeService", EntityCleanupOutcomeService, "_cleanupOutcomeService"),
	moduleSpec("EntityRuntimeParticipationService", EntityRuntimeParticipationService, "_runtimeParticipation"),
	moduleSpec("EntityInstanceBindingService", EntityInstanceBindingService, "_instanceBindingService"),
	moduleSpec("EntityRuntimeSyncService", EntityRuntimeSyncService, "_runtimeSyncService"),
	moduleSpec("EntitySyncContributorRegistry", EntitySyncContributorRegistry, "_syncContributorRegistry"),
	moduleSpec("EntityReplicationRegistry", EntityReplicationRegistry, "_replicationRegistry"),
	moduleSpec("EntityReplicationService", EntityReplicationService, "_replicationService"),
	moduleSpec("EntitySystemRegistry", EntitySystemRegistry, "_systemRegistry"),
	{
		Name = "EntityRuntimeSchedulerService",
		Factory = function(service: any, baseContext: any)
			return EntityRuntimeSchedulerService.new(baseContext, service)
		end,
		CacheAs = "_runtimeScheduler",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{ Name = "EntityValidationService", Module = EntityValidationService },
	{ Name = "EntityLifecyclePolicy", Module = EntityLifecyclePolicy },
	{ Name = "EntityReadinessPolicy", Module = EntityReadinessPolicy },
	{ Name = "EntityRuntimeParticipationPolicy", Module = EntityRuntimeParticipationPolicy },
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	moduleSpec("InitCommand", InitCommand, "_initCommand"),
	moduleSpec("CompileECSKernelCommand", CompileECSKernelCommand, "_compileECSKernelCommand"),
	moduleSpec(
		"FinalizeRuntimeRegistrationCommand",
		FinalizeRuntimeRegistrationCommand,
		"_finalizeRuntimeRegistrationCommand"
	),
	moduleSpec(
		"PrepareRuntimeEntityForRemovalCommand",
		PrepareRuntimeEntityForRemovalCommand,
		"_prepareRuntimeEntityForRemovalCommand"
	),
	moduleSpec("ShutdownRuntimeExecutionCommand", ShutdownRuntimeExecutionCommand, "_shutdownRuntimeExecutionCommand"),
	moduleSpec("HandleStartupFailureCommand", HandleStartupFailureCommand, "_handleStartupFailureCommand"),
	moduleSpec("FinalizeStartupCommand", FinalizeStartupCommand, "_finalizeStartupCommand"),
	moduleSpec("StartCommand", StartCommand, "_startCommand"),
	moduleSpec("DestroyCommand", DestroyCommand, "_destroyCommand"),
	moduleSpec("RunOperationalProofCommand", RunOperationalProofCommand, "_runOperationalProofCommand"),
	moduleSpec("RegisterFeatureSchemaCommand", RegisterFeatureSchemaCommand, "_registerFeatureSchemaCommand"),
	moduleSpec("RegisterEntityFeatureCommand", RegisterEntityFeatureCommand, "_registerEntityFeatureCommand"),
	moduleSpec("RegisterSystemCommand", RegisterSystemCommand, "_registerSystemCommand"),
	moduleSpec("CreateEntityCommand", CreateEntityCommand, "_createEntityCommand"),
	moduleSpec("DestroyEntityCommand", DestroyEntityCommand, "_destroyEntityCommand"),
	moduleSpec("MarkForDestructionCommand", MarkForDestructionCommand, "_markForDestructionCommand"),
	moduleSpec("FlushDestructionQueueCommand", FlushDestructionQueueCommand, "_flushDestructionQueueCommand"),
	moduleSpec("SetCommand", SetCommand, "_setCommand"),
	moduleSpec("AddCommand", AddCommand, "_addCommand"),
	moduleSpec("RemoveCommand", RemoveCommand, "_removeCommand"),
	moduleSpec("TickPhaseCommand", TickPhaseCommand, "_tickPhaseCommand"),
	moduleSpec("TickAllCommand", TickAllCommand, "_tickAllCommand"),
	moduleSpec("RegisterInstanceBindingCommand", RegisterInstanceBindingCommand, "_registerInstanceBindingCommand"),
	moduleSpec("EnableRuntimeBindingCommand", EnableRuntimeBindingCommand, "_enableRuntimeBindingCommand"),
	moduleSpec("EnableRuntimeSyncCommand", EnableRuntimeSyncCommand, "_enableRuntimeSyncCommand"),
	moduleSpec("EnableRuntimeReplicationCommand", EnableRuntimeReplicationCommand, "_enableRuntimeReplicationCommand"),
	moduleSpec("RegisterRuntimeEntityCommand", RegisterRuntimeEntityCommand, "_registerRuntimeEntityCommand"),
	moduleSpec("UnregisterRuntimeEntityCommand", UnregisterRuntimeEntityCommand, "_unregisterRuntimeEntityCommand"),
	moduleSpec("BindEntityInstanceCommand", BindEntityInstanceCommand, "_bindEntityInstanceCommand"),
	moduleSpec("UnbindEntityInstanceCommand", UnbindEntityInstanceCommand, "_unbindEntityInstanceCommand"),
	moduleSpec("QueueEntityBindCommand", QueueEntityBindCommand, "_queueEntityBindCommand"),
	moduleSpec("FlushBindQueueCommand", FlushBindQueueCommand, "_flushBindQueueCommand"),
	moduleSpec("RegisterSyncContributorCommand", RegisterSyncContributorCommand, "_registerSyncContributorCommand"),
	moduleSpec(
		"RegisterReplicationSurfaceCommand",
		RegisterReplicationSurfaceCommand,
		"_registerReplicationSurfaceCommand"
	),
	moduleSpec("RunRuntimeSyncCommand", RunRuntimeSyncCommand, "_runRuntimeSyncCommand"),
	moduleSpec("RunRuntimePollCommand", RunRuntimePollCommand, "_runRuntimePollCommand"),
	moduleSpec("HydrateEntityReplicationCommand", HydrateEntityReplicationCommand, "_hydrateEntityReplicationCommand"),
	moduleSpec(
		"CompleteEntityReplicationBootstrapCommand",
		CompleteEntityReplicationBootstrapCommand,
		"_completeEntityReplicationBootstrapCommand"
	),
	moduleSpec(
		"FlushEntityReplicationReliableCommand",
		FlushEntityReplicationReliableCommand,
		"_flushEntityReplicationReliableCommand"
	),
	moduleSpec(
		"FlushEntityReplicationUnreliableCommand",
		FlushEntityReplicationUnreliableCommand,
		"_flushEntityReplicationUnreliableCommand"
	),
	moduleSpec(
		"FlushEntityReplicationEntityCommand",
		FlushEntityReplicationEntityCommand,
		"_flushEntityReplicationEntityCommand"
	),
	moduleSpec("GetLifecycleStateQuery", GetLifecycleStateQuery, "_getLifecycleStateQuery"),
	moduleSpec("GetReadinessStatusQuery", GetReadinessStatusQuery, "_getReadinessStatusQuery"),
	moduleSpec("GetRegistrationStatusQuery", GetRegistrationStatusQuery, "_getRegistrationStatusQuery"),
	moduleSpec("RunAcceptanceCheckQuery", RunAcceptanceCheckQuery, "_runAcceptanceCheckQuery"),
	moduleSpec("GetEntityValueQuery", GetEntityValueQuery, "_getEntityValueQuery"),
	moduleSpec("HasEntityKeyQuery", HasEntityKeyQuery, "_hasEntityKeyQuery"),
	moduleSpec("QueryEntitiesQuery", QueryEntitiesQuery, "_queryEntitiesQuery"),
	moduleSpec("GetWorldQuery", GetWorldQuery, "_getWorldQuery"),
	moduleSpec("GetFeatureComponentsQuery", GetFeatureComponentsQuery, "_getFeatureComponentsQuery"),
	moduleSpec("GetEntityFactoryQuery", GetEntityFactoryQuery, "_getEntityFactoryQuery"),
	moduleSpec("GetBoundInstanceQuery", GetBoundInstanceQuery, "_getBoundInstanceQuery"),
	moduleSpec("GetBoundEntityQuery", GetBoundEntityQuery, "_getBoundEntityQuery"),
	moduleSpec("BuildRuntimeSnapshotQuery", BuildRuntimeSnapshotQuery, "_buildRuntimeSnapshotQuery"),
	moduleSpec("GetSyncContributorQuery", GetSyncContributorQuery, "_getSyncContributorQuery"),
	moduleSpec("GetReplicationSurfaceQuery", GetReplicationSurfaceQuery, "_getReplicationSurfaceQuery"),
}

local EntityContext = Knit.CreateService({
	Name = "EntityContext",
	Client = {
		EntityBootstrap = Knit.CreateSignal(),
		EntityReliable = Knit.CreateSignal(),
		EntityUnreliable = Knit.CreateSignal(),
		EntityEntity = Knit.CreateSignal(),
	},
	WorldService = {
		Name = "EntityECSWorldService",
		Module = EntityECSWorldService,
		CacheAs = "_worldService",
	},
	Modules = {
		Infrastructure = InfrastructureModules,
		Domain = DomainModules,
		Application = ApplicationModules,
	},
	StartOrder = { "Infrastructure", "Domain", "Application" },
	Teardown = {},
})

local EntityBaseContext = BaseContext.new(EntityContext)

function EntityContext:KnitInit()
	EntityBaseContext:KnitInit()
	local initResult = self:Init()
	if not initResult.success then
		error(
			("EntityContext failed to initialize: [%s] %s"):format(
				tostring(initResult.type),
				tostring(initResult.message)
			)
		)
	end
end

function EntityContext:KnitStart()
	EntityBaseContext:KnitStart()
	local startResult = self:Start()
	if not startResult.success then
		error(
			("EntityContext failed to start: [%s] %s"):format(tostring(startResult.type), tostring(startResult.message))
		)
	end
end

function EntityContext:Init()
	return Catch(function()
		return self._initCommand:Execute()
	end, "EntityContext:Init")
end
function EntityContext:Start()
	return Catch(function()
		return self._startCommand:Execute()
	end, "EntityContext:Start")
end
function EntityContext:_EnsureRuntimeStarted()
	return Catch(function()
		return self._finalizeStartupCommand:Execute()
	end, "EntityContext:_EnsureRuntimeStarted")
end
function EntityContext:Destroy()
	return Catch(function()
		return self._destroyCommand:Execute()
	end, "EntityContext:Destroy")
end
function EntityContext:RunOperationalProof()
	return Catch(function()
		return self._runOperationalProofCommand:Execute()
	end, "EntityContext:RunOperationalProof")
end
function EntityContext:RegisterFeatureSchema(featureName: string, schema: any)
	return Catch(function()
		return self._registerFeatureSchemaCommand:Execute(featureName, schema)
	end, "EntityContext:RegisterFeatureSchema")
end
function EntityContext:RegisterEntityFeature(definition: any)
	return Catch(function()
		return self._registerEntityFeatureCommand:Execute(definition)
	end, "EntityContext:RegisterEntityFeature")
end
function EntityContext:RegisterSystem(phaseName: string, systemSpec: any)
	return Catch(function()
		return self._registerSystemCommand:Execute(phaseName, systemSpec)
	end, "EntityContext:RegisterSystem")
end
function EntityContext:CreateEntity(archetypeName: string, payload: any?)
	return Catch(function()
		return self._createEntityCommand:Execute(archetypeName, payload)
	end, "EntityContext:CreateEntity")
end
function EntityContext:DestroyEntity(entity: number)
	return Catch(function()
		return self._destroyEntityCommand:Execute(entity)
	end, "EntityContext:DestroyEntity")
end
function EntityContext:MarkForDestruction(entity: number)
	return Catch(function()
		return self._markForDestructionCommand:Execute(entity)
	end, "EntityContext:MarkForDestruction")
end
function EntityContext:FlushDestructionQueue()
	return Catch(function()
		return self._flushDestructionQueueCommand:Execute()
	end, "EntityContext:FlushDestructionQueue")
end
function EntityContext:Set(entity: number, key: string, value: any, featureName: string?)
	return Catch(function()
		return self._setCommand:Execute(entity, key, value, featureName)
	end, "EntityContext:Set")
end
function EntityContext:Add(entity: number, key: string, featureName: string?)
	return Catch(function()
		return self._addCommand:Execute(entity, key, featureName)
	end, "EntityContext:Add")
end
function EntityContext:Remove(entity: number, key: string, featureName: string?)
	return Catch(function()
		return self._removeCommand:Execute(entity, key, featureName)
	end, "EntityContext:Remove")
end
function EntityContext:TickPhase(phaseName: string)
	return Catch(function()
		return self._tickPhaseCommand:Execute(phaseName)
	end, "EntityContext:TickPhase")
end
function EntityContext:TickAll()
	return Catch(function()
		return self._tickAllCommand:Execute()
	end, "EntityContext:TickAll")
end
function EntityContext:RegisterInstanceBinding(featureName: string, binding: any)
	return Catch(function()
		return self._registerInstanceBindingCommand:Execute(featureName, binding)
	end, "EntityContext:RegisterInstanceBinding")
end
function EntityContext:EnableRuntimeBinding(featureName: string)
	return Catch(function()
		return self._enableRuntimeBindingCommand:Execute(featureName)
	end, "EntityContext:EnableRuntimeBinding")
end
function EntityContext:EnableRuntimeSync(featureName: string)
	return Catch(function()
		return self._enableRuntimeSyncCommand:Execute(featureName)
	end, "EntityContext:EnableRuntimeSync")
end
function EntityContext:EnableRuntimeReplication(featureName: string)
	return Catch(function()
		return self._enableRuntimeReplicationCommand:Execute(featureName)
	end, "EntityContext:EnableRuntimeReplication")
end
function EntityContext:RegisterRuntimeEntity(entity: number)
	return Catch(function()
		return self._registerRuntimeEntityCommand:Execute(entity)
	end, "EntityContext:RegisterRuntimeEntity")
end
function EntityContext:UnregisterRuntimeEntity(entity: number)
	return Catch(function()
		return self._unregisterRuntimeEntityCommand:Execute(entity)
	end, "EntityContext:UnregisterRuntimeEntity")
end
function EntityContext:BindEntityInstance(entity: number)
	return Catch(function()
		return self._bindEntityInstanceCommand:Execute(entity)
	end, "EntityContext:BindEntityInstance")
end
function EntityContext:UnbindEntityInstance(entity: number)
	return Catch(function()
		return self._unbindEntityInstanceCommand:Execute(entity)
	end, "EntityContext:UnbindEntityInstance")
end
function EntityContext:QueueEntityBind(entity: number)
	return Catch(function()
		return self._queueEntityBindCommand:Execute(entity)
	end, "EntityContext:QueueEntityBind")
end
function EntityContext:FlushBindQueue()
	return Catch(function()
		return self._flushBindQueueCommand:Execute()
	end, "EntityContext:FlushBindQueue")
end
function EntityContext:RegisterSyncContributor(featureName: string, payload: any)
	return Catch(function()
		return self._registerSyncContributorCommand:Execute(featureName, payload)
	end, "EntityContext:RegisterSyncContributor")
end
function EntityContext:RegisterReplicationSurface(featureName: string, payload: any)
	return Catch(function()
		return self._registerReplicationSurfaceCommand:Execute(featureName, payload)
	end, "EntityContext:RegisterReplicationSurface")
end
function EntityContext:RunRuntimeSync()
	return Catch(function()
		return self._runRuntimeSyncCommand:Execute()
	end, "EntityContext:RunRuntimeSync")
end
function EntityContext:RunRuntimePoll()
	return Catch(function()
		return self._runRuntimePollCommand:Execute()
	end, "EntityContext:RunRuntimePoll")
end
function EntityContext:HydrateEntityReplication(player: Player)
	return Catch(function()
		return self._hydrateEntityReplicationCommand:Execute(player)
	end, "EntityContext:HydrateEntityReplication")
end
function EntityContext:CompleteEntityReplicationBootstrap(player: Player)
	return Catch(function()
		return self._completeEntityReplicationBootstrapCommand:Execute(player)
	end, "EntityContext:CompleteEntityReplicationBootstrap")
end
function EntityContext:FlushEntityReplicationReliable()
	return Catch(function()
		return self._flushEntityReplicationReliableCommand:Execute()
	end, "EntityContext:FlushEntityReplicationReliable")
end
function EntityContext:FlushEntityReplicationUnreliable()
	return Catch(function()
		return self._flushEntityReplicationUnreliableCommand:Execute()
	end, "EntityContext:FlushEntityReplicationUnreliable")
end
function EntityContext:FlushEntityReplicationEntity(entity: number)
	return Catch(function()
		return self._flushEntityReplicationEntityCommand:Execute(entity)
	end, "EntityContext:FlushEntityReplicationEntity")
end
function EntityContext:GetLifecycleState()
	return Catch(function()
		return self._getLifecycleStateQuery:Execute()
	end, "EntityContext:GetLifecycleState")
end
function EntityContext:GetReadinessStatus()
	return Catch(function()
		return self._getReadinessStatusQuery:Execute()
	end, "EntityContext:GetReadinessStatus")
end
function EntityContext:GetRegistrationStatus()
	return Catch(function()
		return self._getRegistrationStatusQuery:Execute()
	end, "EntityContext:GetRegistrationStatus")
end
function EntityContext:RunAcceptanceCheck()
	return Catch(function()
		return self._runAcceptanceCheckQuery:Execute()
	end, "EntityContext:RunAcceptanceCheck")
end
function EntityContext:Get(entity: number, key: string, featureName: string?)
	return Catch(function()
		return self._getEntityValueQuery:Execute(entity, key, featureName)
	end, "EntityContext:Get")
end
function EntityContext:Has(entity: number, key: string, featureName: string?)
	return Catch(function()
		return self._hasEntityKeyQuery:Execute(entity, key, featureName)
	end, "EntityContext:Has")
end
function EntityContext:Query(querySpec: any)
	return Catch(function()
		return self._queryEntitiesQuery:Execute(querySpec)
	end, "EntityContext:Query")
end
function EntityContext:GetWorld()
	return Catch(function()
		return self._getWorldQuery:Execute()
	end, "EntityContext:GetWorld")
end
function EntityContext:GetFeatureComponents(featureName: string)
	return Catch(function()
		return self._getFeatureComponentsQuery:Execute(featureName)
	end, "EntityContext:GetFeatureComponents")
end
function EntityContext:GetEntityFactory()
	return Catch(function()
		return self._getEntityFactoryQuery:Execute()
	end, "EntityContext:GetEntityFactory")
end
function EntityContext:GetBoundInstance(entity: number)
	return Catch(function()
		return self._getBoundInstanceQuery:Execute(entity)
	end, "EntityContext:GetBoundInstance")
end
function EntityContext:GetBoundEntity(instance: Instance)
	return Catch(function()
		return self._getBoundEntityQuery:Execute(instance)
	end, "EntityContext:GetBoundEntity")
end
function EntityContext:BuildRuntimeSnapshot(entity: number)
	return Catch(function()
		return self._buildRuntimeSnapshotQuery:Execute(entity)
	end, "EntityContext:BuildRuntimeSnapshot")
end
function EntityContext:GetSyncContributor(featureName: string)
	return Catch(function()
		return self._getSyncContributorQuery:Execute(featureName)
	end, "EntityContext:GetSyncContributor")
end
function EntityContext:GetReplicationSurface(featureName: string)
	return Catch(function()
		return self._getReplicationSurfaceQuery:Execute(featureName)
	end, "EntityContext:GetReplicationSurface")
end

function EntityContext.Client:RequestEntityReplication(player: Player): boolean
	local result = self.Server:HydrateEntityReplication(player)
	return result.success and result.value == true
end

function EntityContext.Client:AcknowledgeEntityReplicationBootstrap(player: Player): boolean
	local result = self.Server:CompleteEntityReplicationBootstrap(player)
	return result.success and result.value == true
end

return EntityContext
