--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local UnitTypes = require(ReplicatedStorage.Contexts.Unit.Types.UnitTypes)

local UnitECSWorldService = require(script.Parent.Infrastructure.ECS.UnitECSWorldService)
local UnitComponentRegistry = require(script.Parent.Infrastructure.ECS.UnitComponentRegistry)
local UnitEntityFactory = require(script.Parent.Infrastructure.ECS.UnitEntityFactory)
local UnitInstanceFactory = require(script.Parent.Infrastructure.ECS.UnitInstanceFactory)
local UnitCombatAdapterService = require(script.Parent.Infrastructure.Services.UnitCombatAdapterService)
local UnitECSReplicationService = require(script.Parent.Infrastructure.Persistence.UnitECSReplicationService)
local UnitGameObjectSyncService = require(script.Parent.Infrastructure.Persistence.UnitGameObjectSyncService)
local UnitSpawnPolicy = require(script.Parent.UnitDomain.Policies.UnitSpawnPolicy)

local SpawnUnitCommand = require(script.Parent.Application.Commands.SpawnUnitCommand)
local DespawnUnitCommand = require(script.Parent.Application.Commands.DespawnUnitCommand)
local CleanupUnitsCommand = require(script.Parent.Application.Commands.CleanupUnitsCommand)
local GetActiveUnitsQuery = require(script.Parent.Application.Queries.GetActiveUnitsQuery)
local GetOwnerUnitCountQuery = require(script.Parent.Application.Queries.GetOwnerUnitCountQuery)

type SpawnUnitRequest = UnitTypes.SpawnUnitRequest
type SpawnUnitResult = UnitTypes.SpawnUnitResult

local Catch = Result.Catch
local Ok = Result.Ok

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ClientSignals",
		Factory = function(service: any, _baseContext: any)
			return service.Client
		end,
	},
	{
		Name = "UnitComponentRegistry",
		Module = UnitComponentRegistry,
	},
	{
		Name = "UnitEntityFactory",
		Module = UnitEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "UnitInstanceFactory",
		Module = UnitInstanceFactory,
		CacheAs = "_instanceFactory",
	},
	{
		Name = "UnitCombatAdapterService",
		Module = UnitCombatAdapterService,
		CacheAs = "_combatAdapterService",
	},
	{
		Name = "UnitECSReplicationService",
		Module = UnitECSReplicationService,
		CacheAs = "_replicationService",
	},
	{
		Name = "UnitGameObjectSyncService",
		Module = UnitGameObjectSyncService,
		CacheAs = "_syncService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "UnitSpawnPolicy",
		Module = UnitSpawnPolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "SpawnUnitCommand",
		Module = SpawnUnitCommand,
		CacheAs = "_spawnUnitCommand",
	},
	{
		Name = "DespawnUnitCommand",
		Module = DespawnUnitCommand,
		CacheAs = "_despawnUnitCommand",
	},
	{
		Name = "CleanupUnitsCommand",
		Module = CleanupUnitsCommand,
		CacheAs = "_cleanupUnitsCommand",
	},
	{
		Name = "GetActiveUnitsQuery",
		Module = GetActiveUnitsQuery,
		CacheAs = "_getActiveUnitsQuery",
	},
	{
		Name = "GetOwnerUnitCountQuery",
		Module = GetOwnerUnitCountQuery,
		CacheAs = "_getOwnerUnitCountQuery",
	},
}

local UnitModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

local UnitContext = Knit.CreateService({
	Name = "UnitContext",
	Client = {
		UnitBootstrap = Knit.CreateSignal(),
		UnitReliable = Knit.CreateSignal(),
		UnitUnreliable = Knit.CreateSignal(),
		UnitEntity = Knit.CreateSignal(),
	},
	WorldService = {
		Name = "UnitECSWorldService",
		Module = UnitECSWorldService,
	},
	Modules = UnitModules,
	ExternalServices = {
		{ Name = "CombatContext" },
		{ Name = "TeamContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
		},
	},
})

local UnitBaseContext = BaseContext.new(UnitContext)

function UnitContext:KnitInit()
	UnitBaseContext:KnitInit()
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
end

function UnitContext:KnitStart()
	UnitBaseContext:KnitStart()
	UnitBaseContext:RegisterSyncSystem("_syncService", nil, "UnitSync")
	UnitBaseContext:RegisterMethodSystem("UnitSync", "_replicationService", "FlushReliable")
	UnitBaseContext:RegisterMethodSystem("UnitSync", "_replicationService", "FlushUnreliable")
	self._combatAdapterService:ConfigureRuntimeOwner(self)
	local registerActorTypeResult = self._combatAdapterService:RegisterActorType()
	if not registerActorTypeResult.success then
		Result.MentionError("Unit:KnitStart", "Failed to register unit combat actor type", {
			CauseType = registerActorTypeResult.type,
			CauseMessage = registerActorTypeResult.message,
			Details = registerActorTypeResult.data,
		}, registerActorTypeResult.type)
		error(
			string.format(
				"UnitContext failed to register combat actor type on April 30, 2026 startup path: [%s] %s",
				tostring(registerActorTypeResult.type),
				tostring(registerActorTypeResult.message)
			)
		)
	end

	UnitBaseContext:OnContextEvent("Run", "RunEnded", function()
		self:_OnRunEnded()
	end, "_runEndedConnection")

	UnitBaseContext:OnPlayerRemoving(function(player: Player)
		self:CleanupOwner("Player", tostring(player.UserId))
	end, "_playerRemovingConnection")
end

function UnitContext:SpawnUnit(request: SpawnUnitRequest): Result.Result<SpawnUnitResult>
	return Catch(function()
		return self._spawnUnitCommand:Execute(request)
	end, "Unit:SpawnUnit")
end

function UnitContext:DespawnUnit(entity: number): Result.Result<boolean>
	return Catch(function()
		return self._despawnUnitCommand:Execute(entity)
	end, "Unit:DespawnUnit")
end

function UnitContext:CleanupOwner(ownerKind: string, ownerId: string): Result.Result<boolean>
	return Catch(function()
		return self._cleanupUnitsCommand:Execute(ownerKind, ownerId)
	end, "Unit:CleanupOwner")
end

function UnitContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupUnitsCommand:Execute(nil, nil)
	end, "Unit:CleanupAll")
end

function UnitContext:GetActiveUnits(): Result.Result<{ number }>
	return Catch(function()
		return self._getActiveUnitsQuery:Execute()
	end, "Unit:GetActiveUnits")
end

function UnitContext:GetOwnerUnitCount(ownerKind: string, ownerId: string): Result.Result<number>
	return Catch(function()
		return self._getOwnerUnitCountQuery:Execute(ownerKind, ownerId)
	end, "Unit:GetOwnerUnitCount")
end

function UnitContext:GetEntityFactory(): Result.Result<any>
	return Ok(self._entityFactory)
end

function UnitContext:GetInstanceFactory(): Result.Result<any>
	return Ok(self._instanceFactory)
end

function UnitContext:GetGameObjectSyncService(): Result.Result<any>
	return Ok(self._syncService)
end

function UnitContext:GetReplicationService(): Result.Result<any>
	return Ok(self._replicationService)
end

function UnitContext:GetSchedulerBindingStatus(targetField: string): Result.Result<any>
	return Ok(UnitBaseContext:GetSchedulerBindingStatus(targetField))
end

function UnitContext:_OnRunEnded()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Unit:RunEnded", "Failed to cleanup units after run ended", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function UnitContext:_BeforeDestroy()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Unit:Destroy", "Cleanup failed during destroy", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function UnitContext:Destroy()
	local destroyResult = UnitBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Unit:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

function UnitContext.Client:RequestUnitReplication(player: Player): boolean
	return self.Server._replicationService:HydratePlayer(player)
end

function UnitContext.Client:AcknowledgeUnitReplicationBootstrap(player: Player): boolean
	return self.Server._replicationService:CompleteBootstrap(player)
end

return UnitContext
