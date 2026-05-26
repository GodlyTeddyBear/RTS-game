--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local EntityLifecycleStateMachine = require(script.Parent.Infrastructure.Services.EntityLifecycleStateMachine)
local EntityAIActorTypeRegistry = require(script.Parent.Infrastructure.AI.EntityAIActorTypeRegistry)
local EntityAIEntityRegistry = require(script.Parent.Infrastructure.AI.EntityAIEntityRegistry)
local EntityCombatAIRuntimeBridge = require(script.Parent.Infrastructure.AI.EntityCombatAIRuntimeBridge)
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
local EntityRuntimeParticipationService = require(script.Parent.Infrastructure.Runtime.EntityRuntimeParticipationService)
local EntityRuntimeSnapshotBuilder = require(script.Parent.Infrastructure.Runtime.EntityRuntimeSnapshotBuilder)
local EntityRevealService = require(script.Parent.Infrastructure.Services.EntityRevealService)

local EntityValidationService = require(script.Parent.EntityDomain.Services.EntityValidationService)
local EntityAIActionStateService = require(script.Parent.EntityDomain.Services.EntityAIActionStateService)
local EntityLifecyclePolicy = require(script.Parent.EntityDomain.Policies.EntityLifecyclePolicy)
local EntityReadinessPolicy = require(script.Parent.EntityDomain.Policies.EntityReadinessPolicy)

local EntityKernelService = require(script.Parent.Application.Services.EntityKernelService)

local InitCommand = require(script.Parent.Application.Commands.InitCommand)
local StartCommand = require(script.Parent.Application.Commands.StartCommand)
local DestroyCommand = require(script.Parent.Application.Commands.DestroyCommand)
local RunOperationalProofCommand = require(script.Parent.Application.Commands.RunOperationalProofCommand)
local RegisterFeatureSchemaCommand = require(script.Parent.Application.Commands.RegisterFeatureSchemaCommand)
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
local FlushEntityReplicationEntityCommand = require(script.Parent.Application.Commands.FlushEntityReplicationEntityCommand)
local RegisterAIActorTypeCommand = require(script.Parent.Application.Commands.RegisterAIActorTypeCommand)
local RegisterAIEntityCommand = require(script.Parent.Application.Commands.RegisterAIEntityCommand)
local UnregisterAIEntityCommand = require(script.Parent.Application.Commands.UnregisterAIEntityCommand)

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
local GetAIActorHandleQuery = require(script.Parent.Application.Queries.GetAIActorHandleQuery)
local GetAIRegistrationQuery = require(script.Parent.Application.Queries.GetAIRegistrationQuery)

local Catch = Result.Catch

local function commandSpec(name: string, module: any, cacheAs: string): BaseContext.TModuleSpec
	return {
		Name = name,
		Module = module,
		CacheAs = cacheAs,
	}
end

local function querySpec(name: string, module: any, cacheAs: string): BaseContext.TModuleSpec
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
		Name = "EntityLifecycleStateMachine",
		Module = EntityLifecycleStateMachine,
		CacheAs = "_lifecycle",
	},
	{
		Name = "EntitySchemaRegistry",
		Module = EntitySchemaRegistry,
		CacheAs = "_schemaRegistry",
	},
	{
		Name = "EntityEntityFactory",
		Module = EntityEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "EntityInstanceBindingRegistry",
		Module = EntityInstanceBindingRegistry,
		CacheAs = "_instanceBindingRegistry",
	},
	{
		Name = "EntityRevealService",
		Module = EntityRevealService,
		CacheAs = "_revealService",
	},
	{
		Name = "EntityRuntimeSnapshotBuilder",
		Module = EntityRuntimeSnapshotBuilder,
		CacheAs = "_runtimeSnapshotBuilder",
	},
	{
		Name = "EntityRuntimeParticipationService",
		Module = EntityRuntimeParticipationService,
		CacheAs = "_runtimeParticipation",
	},
	{
		Name = "EntityInstanceBindingService",
		Module = EntityInstanceBindingService,
		CacheAs = "_instanceBindingService",
	},
	{
		Name = "EntityRuntimeSyncService",
		Module = EntityRuntimeSyncService,
		CacheAs = "_runtimeSyncService",
	},
	{
		Name = "EntitySyncContributorRegistry",
		Module = EntitySyncContributorRegistry,
		CacheAs = "_syncContributorRegistry",
	},
	{
		Name = "EntityReplicationRegistry",
		Module = EntityReplicationRegistry,
		CacheAs = "_replicationRegistry",
	},
	{
		Name = "EntityReplicationService",
		Module = EntityReplicationService,
		CacheAs = "_replicationService",
	},
	{
		Name = "EntityAIActorTypeRegistry",
		Module = EntityAIActorTypeRegistry,
		CacheAs = "_aiActorTypeRegistry",
	},
	{
		Name = "EntityAIEntityRegistry",
		Module = EntityAIEntityRegistry,
		CacheAs = "_aiEntityRegistry",
	},
	{
		Name = "EntityCombatAIRuntimeBridge",
		Module = EntityCombatAIRuntimeBridge,
		CacheAs = "_combatAIRuntimeBridge",
	},
	{
		Name = "EntitySystemRegistry",
		Module = EntitySystemRegistry,
		CacheAs = "_systemRegistry",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "EntityValidationService",
		Module = EntityValidationService,
	},
	{
		Name = "EntityAIActionStateService",
		Module = EntityAIActionStateService,
	},
	{
		Name = "EntityLifecyclePolicy",
		Module = EntityLifecyclePolicy,
	},
	{
		Name = "EntityReadinessPolicy",
		Module = EntityReadinessPolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "EntityKernelService",
		Factory = function(service: any, baseContext: any)
			return EntityKernelService.new(baseContext, service)
		end,
		CacheAs = "_kernelService",
	},
	commandSpec("InitCommand", InitCommand, "_initCommand"),
	commandSpec("StartCommand", StartCommand, "_startCommand"),
	commandSpec("DestroyCommand", DestroyCommand, "_destroyCommand"),
	commandSpec("RunOperationalProofCommand", RunOperationalProofCommand, "_runOperationalProofCommand"),
	commandSpec("RegisterFeatureSchemaCommand", RegisterFeatureSchemaCommand, "_registerFeatureSchemaCommand"),
	commandSpec("RegisterSystemCommand", RegisterSystemCommand, "_registerSystemCommand"),
	commandSpec("CreateEntityCommand", CreateEntityCommand, "_createEntityCommand"),
	commandSpec("DestroyEntityCommand", DestroyEntityCommand, "_destroyEntityCommand"),
	commandSpec("MarkForDestructionCommand", MarkForDestructionCommand, "_markForDestructionCommand"),
	commandSpec("FlushDestructionQueueCommand", FlushDestructionQueueCommand, "_flushDestructionQueueCommand"),
	commandSpec("SetCommand", SetCommand, "_setCommand"),
	commandSpec("AddCommand", AddCommand, "_addCommand"),
	commandSpec("RemoveCommand", RemoveCommand, "_removeCommand"),
	commandSpec("TickPhaseCommand", TickPhaseCommand, "_tickPhaseCommand"),
	commandSpec("TickAllCommand", TickAllCommand, "_tickAllCommand"),
	commandSpec("RegisterInstanceBindingCommand", RegisterInstanceBindingCommand, "_registerInstanceBindingCommand"),
	commandSpec("EnableRuntimeBindingCommand", EnableRuntimeBindingCommand, "_enableRuntimeBindingCommand"),
	commandSpec("EnableRuntimeSyncCommand", EnableRuntimeSyncCommand, "_enableRuntimeSyncCommand"),
	commandSpec(
		"EnableRuntimeReplicationCommand",
		EnableRuntimeReplicationCommand,
		"_enableRuntimeReplicationCommand"
	),
	commandSpec("RegisterRuntimeEntityCommand", RegisterRuntimeEntityCommand, "_registerRuntimeEntityCommand"),
	commandSpec("UnregisterRuntimeEntityCommand", UnregisterRuntimeEntityCommand, "_unregisterRuntimeEntityCommand"),
	commandSpec("BindEntityInstanceCommand", BindEntityInstanceCommand, "_bindEntityInstanceCommand"),
	commandSpec("UnbindEntityInstanceCommand", UnbindEntityInstanceCommand, "_unbindEntityInstanceCommand"),
	commandSpec("QueueEntityBindCommand", QueueEntityBindCommand, "_queueEntityBindCommand"),
	commandSpec("FlushBindQueueCommand", FlushBindQueueCommand, "_flushBindQueueCommand"),
	commandSpec("RegisterSyncContributorCommand", RegisterSyncContributorCommand, "_registerSyncContributorCommand"),
	commandSpec(
		"RegisterReplicationSurfaceCommand",
		RegisterReplicationSurfaceCommand,
		"_registerReplicationSurfaceCommand"
	),
	commandSpec("RunRuntimeSyncCommand", RunRuntimeSyncCommand, "_runRuntimeSyncCommand"),
	commandSpec("RunRuntimePollCommand", RunRuntimePollCommand, "_runRuntimePollCommand"),
	commandSpec("HydrateEntityReplicationCommand", HydrateEntityReplicationCommand, "_hydrateEntityReplicationCommand"),
	commandSpec(
		"CompleteEntityReplicationBootstrapCommand",
		CompleteEntityReplicationBootstrapCommand,
		"_completeEntityReplicationBootstrapCommand"
	),
	commandSpec(
		"FlushEntityReplicationReliableCommand",
		FlushEntityReplicationReliableCommand,
		"_flushEntityReplicationReliableCommand"
	),
	commandSpec(
		"FlushEntityReplicationUnreliableCommand",
		FlushEntityReplicationUnreliableCommand,
		"_flushEntityReplicationUnreliableCommand"
	),
	commandSpec(
		"FlushEntityReplicationEntityCommand",
		FlushEntityReplicationEntityCommand,
		"_flushEntityReplicationEntityCommand"
	),
	commandSpec("RegisterAIActorTypeCommand", RegisterAIActorTypeCommand, "_registerAIActorTypeCommand"),
	commandSpec("RegisterAIEntityCommand", RegisterAIEntityCommand, "_registerAIEntityCommand"),
	commandSpec("UnregisterAIEntityCommand", UnregisterAIEntityCommand, "_unregisterAIEntityCommand"),
	querySpec("GetLifecycleStateQuery", GetLifecycleStateQuery, "_getLifecycleStateQuery"),
	querySpec("GetReadinessStatusQuery", GetReadinessStatusQuery, "_getReadinessStatusQuery"),
	querySpec("GetRegistrationStatusQuery", GetRegistrationStatusQuery, "_getRegistrationStatusQuery"),
	querySpec("RunAcceptanceCheckQuery", RunAcceptanceCheckQuery, "_runAcceptanceCheckQuery"),
	querySpec("GetEntityValueQuery", GetEntityValueQuery, "_getEntityValueQuery"),
	querySpec("HasEntityKeyQuery", HasEntityKeyQuery, "_hasEntityKeyQuery"),
	querySpec("QueryEntitiesQuery", QueryEntitiesQuery, "_queryEntitiesQuery"),
	querySpec("GetWorldQuery", GetWorldQuery, "_getWorldQuery"),
	querySpec("GetFeatureComponentsQuery", GetFeatureComponentsQuery, "_getFeatureComponentsQuery"),
	querySpec("GetEntityFactoryQuery", GetEntityFactoryQuery, "_getEntityFactoryQuery"),
	querySpec("GetBoundInstanceQuery", GetBoundInstanceQuery, "_getBoundInstanceQuery"),
	querySpec("GetBoundEntityQuery", GetBoundEntityQuery, "_getBoundEntityQuery"),
	querySpec("BuildRuntimeSnapshotQuery", BuildRuntimeSnapshotQuery, "_buildRuntimeSnapshotQuery"),
	querySpec("GetSyncContributorQuery", GetSyncContributorQuery, "_getSyncContributorQuery"),
	querySpec("GetReplicationSurfaceQuery", GetReplicationSurfaceQuery, "_getReplicationSurfaceQuery"),
	querySpec("GetAIActorHandleQuery", GetAIActorHandleQuery, "_getAIActorHandleQuery"),
	querySpec("GetAIRegistrationQuery", GetAIRegistrationQuery, "_getAIRegistrationQuery"),
}

local EntityModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
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
	Modules = EntityModules,
	StartOrder = { "Infrastructure", "Domain", "Application" },
	ExternalServices = {
		{ Name = "CombatContext", CacheAs = "_combatContext" },
	},
	Teardown = {},
})

local EntityBaseContext = BaseContext.new(EntityContext)

local function delegate(fieldName: string, label: string)
	return function(self: any, ...: any)
		return Catch(function()
			return self[fieldName]:Execute(...)
		end, label)
	end
end

function EntityContext:KnitInit()
	EntityBaseContext:KnitInit()

	local initResult = self:Init()
	if not initResult.success then
		error(("EntityContext failed to initialize: [%s] %s"):format(tostring(initResult.type), tostring(initResult.message)))
	end
end

function EntityContext:KnitStart()
	EntityBaseContext:KnitStart()

	local startResult = self:Start()
	if not startResult.success then
		error(("EntityContext failed to start: [%s] %s"):format(tostring(startResult.type), tostring(startResult.message)))
	end
end

EntityContext.Init = delegate("_initCommand", "EntityContext:Init")
EntityContext.Start = delegate("_startCommand", "EntityContext:Start")
EntityContext.Destroy = delegate("_destroyCommand", "EntityContext:Destroy")
EntityContext.RunOperationalProof = delegate("_runOperationalProofCommand", "EntityContext:RunOperationalProof")
EntityContext.RegisterFeatureSchema = delegate("_registerFeatureSchemaCommand", "EntityContext:RegisterFeatureSchema")
EntityContext.RegisterSystem = delegate("_registerSystemCommand", "EntityContext:RegisterSystem")
EntityContext.CreateEntity = delegate("_createEntityCommand", "EntityContext:CreateEntity")
EntityContext.DestroyEntity = delegate("_destroyEntityCommand", "EntityContext:DestroyEntity")
EntityContext.MarkForDestruction = delegate("_markForDestructionCommand", "EntityContext:MarkForDestruction")
EntityContext.FlushDestructionQueue = delegate("_flushDestructionQueueCommand", "EntityContext:FlushDestructionQueue")
EntityContext.Set = delegate("_setCommand", "EntityContext:Set")
EntityContext.Add = delegate("_addCommand", "EntityContext:Add")
EntityContext.Remove = delegate("_removeCommand", "EntityContext:Remove")
EntityContext.TickPhase = delegate("_tickPhaseCommand", "EntityContext:TickPhase")
EntityContext.TickAll = delegate("_tickAllCommand", "EntityContext:TickAll")
EntityContext.RegisterInstanceBinding = delegate("_registerInstanceBindingCommand", "EntityContext:RegisterInstanceBinding")
EntityContext.EnableRuntimeBinding = delegate("_enableRuntimeBindingCommand", "EntityContext:EnableRuntimeBinding")
EntityContext.EnableRuntimeSync = delegate("_enableRuntimeSyncCommand", "EntityContext:EnableRuntimeSync")
EntityContext.EnableRuntimeReplication =
	delegate("_enableRuntimeReplicationCommand", "EntityContext:EnableRuntimeReplication")
EntityContext.RegisterRuntimeEntity = delegate("_registerRuntimeEntityCommand", "EntityContext:RegisterRuntimeEntity")
EntityContext.UnregisterRuntimeEntity =
	delegate("_unregisterRuntimeEntityCommand", "EntityContext:UnregisterRuntimeEntity")
EntityContext.BindEntityInstance = delegate("_bindEntityInstanceCommand", "EntityContext:BindEntityInstance")
EntityContext.UnbindEntityInstance = delegate("_unbindEntityInstanceCommand", "EntityContext:UnbindEntityInstance")
EntityContext.QueueEntityBind = delegate("_queueEntityBindCommand", "EntityContext:QueueEntityBind")
EntityContext.FlushBindQueue = delegate("_flushBindQueueCommand", "EntityContext:FlushBindQueue")
EntityContext.RegisterSyncContributor = delegate("_registerSyncContributorCommand", "EntityContext:RegisterSyncContributor")
EntityContext.RegisterReplicationSurface =
	delegate("_registerReplicationSurfaceCommand", "EntityContext:RegisterReplicationSurface")
EntityContext.RunRuntimeSync = delegate("_runRuntimeSyncCommand", "EntityContext:RunRuntimeSync")
EntityContext.RunRuntimePoll = delegate("_runRuntimePollCommand", "EntityContext:RunRuntimePoll")
EntityContext.HydrateEntityReplication = delegate("_hydrateEntityReplicationCommand", "EntityContext:HydrateEntityReplication")
EntityContext.CompleteEntityReplicationBootstrap = delegate(
	"_completeEntityReplicationBootstrapCommand",
	"EntityContext:CompleteEntityReplicationBootstrap"
)
EntityContext.FlushEntityReplicationReliable =
	delegate("_flushEntityReplicationReliableCommand", "EntityContext:FlushEntityReplicationReliable")
EntityContext.FlushEntityReplicationUnreliable =
	delegate("_flushEntityReplicationUnreliableCommand", "EntityContext:FlushEntityReplicationUnreliable")
EntityContext.FlushEntityReplicationEntity =
	delegate("_flushEntityReplicationEntityCommand", "EntityContext:FlushEntityReplicationEntity")
EntityContext.RegisterAIActorType = delegate("_registerAIActorTypeCommand", "EntityContext:RegisterAIActorType")
EntityContext.RegisterAIEntity = delegate("_registerAIEntityCommand", "EntityContext:RegisterAIEntity")
EntityContext.UnregisterAIEntity = delegate("_unregisterAIEntityCommand", "EntityContext:UnregisterAIEntity")
EntityContext.GetLifecycleState = delegate("_getLifecycleStateQuery", "EntityContext:GetLifecycleState")
EntityContext.GetReadinessStatus = delegate("_getReadinessStatusQuery", "EntityContext:GetReadinessStatus")
EntityContext.GetRegistrationStatus = delegate("_getRegistrationStatusQuery", "EntityContext:GetRegistrationStatus")
EntityContext.RunAcceptanceCheck = delegate("_runAcceptanceCheckQuery", "EntityContext:RunAcceptanceCheck")
EntityContext.Get = delegate("_getEntityValueQuery", "EntityContext:Get")
EntityContext.Has = delegate("_hasEntityKeyQuery", "EntityContext:Has")
EntityContext.Query = delegate("_queryEntitiesQuery", "EntityContext:Query")
EntityContext.GetWorld = delegate("_getWorldQuery", "EntityContext:GetWorld")
EntityContext.GetFeatureComponents = delegate("_getFeatureComponentsQuery", "EntityContext:GetFeatureComponents")
EntityContext.GetEntityFactory = delegate("_getEntityFactoryQuery", "EntityContext:GetEntityFactory")
EntityContext.GetBoundInstance = delegate("_getBoundInstanceQuery", "EntityContext:GetBoundInstance")
EntityContext.GetBoundEntity = delegate("_getBoundEntityQuery", "EntityContext:GetBoundEntity")
EntityContext.BuildRuntimeSnapshot = delegate("_buildRuntimeSnapshotQuery", "EntityContext:BuildRuntimeSnapshot")
EntityContext.GetSyncContributor = delegate("_getSyncContributorQuery", "EntityContext:GetSyncContributor")
EntityContext.GetReplicationSurface = delegate("_getReplicationSurfaceQuery", "EntityContext:GetReplicationSurface")
EntityContext.GetAIActorHandle = delegate("_getAIActorHandleQuery", "EntityContext:GetAIActorHandle")
EntityContext.GetAIRegistration = delegate("_getAIRegistrationQuery", "EntityContext:GetAIRegistration")

function EntityContext.Client:RequestEntityReplication(player: Player): boolean
	local result = self.Server:HydrateEntityReplication(player)
	return result.success and result.value == true
end

function EntityContext.Client:AcknowledgeEntityReplicationBootstrap(player: Player): boolean
	local result = self.Server:CompleteEntityReplicationBootstrap(player)
	return result.success and result.value == true
end

return EntityContext
