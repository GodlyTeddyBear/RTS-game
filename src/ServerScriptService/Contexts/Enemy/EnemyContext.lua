--!strict

--[[
	Module: EnemyContext
	Purpose: Owns the authoritative enemy ECS world, spawn and despawn use-cases, and run-lifecycle cleanup.
	Used In System: Started by Knit on the server and called by combat, wave, and shutdown event handlers.
	High-Level Flow: Register infrastructure -> initialize ECS modules -> expose commands and queries -> clean up on run end.
	Boundaries: Owns enemy orchestration only; does not own combat targeting, wave composition, or client animation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local EnemyECSWorldService = require(script.Parent.Infrastructure.ECS.EnemyECSWorldService)
local EnemyComponentRegistry = require(script.Parent.Infrastructure.ECS.EnemyComponentRegistry)
local EnemyEntityFactory = require(script.Parent.Infrastructure.ECS.EnemyEntityFactory)
local EnemyModelFactory = require(script.Parent.Infrastructure.Services.EnemyModelFactory)
local EnemyGameObjectSyncService = require(script.Parent.Infrastructure.Persistence.EnemyGameObjectSyncService)
local EnemySpawnPolicy = require(script.Parent.EnemyDomain.Policies.EnemySpawnPolicy)

local SpawnEnemyCommand = require(script.Parent.Application.Commands.SpawnEnemy)
local DespawnEnemyCommand = require(script.Parent.Application.Commands.DespawnEnemy)
local ApplyDamageEnemyCommand = require(script.Parent.Application.Commands.ApplyDamageEnemy)
local CleanupAllEnemiesCommand = require(script.Parent.Application.Commands.CleanupAllEnemies)
local GetAliveEnemiesQuery = require(script.Parent.Application.Queries.GetAliveEnemiesQuery)
local GetEnemyCountQuery = require(script.Parent.Application.Queries.GetEnemyCountQuery)

local Catch = Result.Catch
local Ok = Result.Ok

-- [Dependencies]
local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "EnemyComponentRegistry",
		Module = EnemyComponentRegistry,
	},
	{
		Name = "EnemyEntityFactory",
		Module = EnemyEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "EnemyModelFactory",
		Module = EnemyModelFactory,
		CacheAs = "_modelFactory",
	},
	{
		Name = "EnemyGameObjectSyncService",
		Module = EnemyGameObjectSyncService,
		CacheAs = "_syncService",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "EnemySpawnPolicy",
		Module = EnemySpawnPolicy,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "SpawnEnemyCommand",
		Module = SpawnEnemyCommand,
		CacheAs = "_spawnEnemyCommand",
	},
	{
		Name = "DespawnEnemyCommand",
		Module = DespawnEnemyCommand,
		CacheAs = "_despawnEnemyCommand",
	},
	{
		Name = "ApplyDamageEnemyCommand",
		Module = ApplyDamageEnemyCommand,
		CacheAs = "_applyDamageEnemyCommand",
	},
	{
		Name = "CleanupAllEnemiesCommand",
		Module = CleanupAllEnemiesCommand,
		CacheAs = "_cleanupAllEnemiesCommand",
	},
	{
		Name = "GetAliveEnemiesQuery",
		Module = GetAliveEnemiesQuery,
		CacheAs = "_getAliveEnemiesQuery",
	},
	{
		Name = "GetEnemyCountQuery",
		Module = GetEnemyCountQuery,
		CacheAs = "_getEnemyCountQuery",
	},
}

local EnemyModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

--[=[
	@class EnemyContext
	Orchestrates the authoritative enemy lane stack for spawn, model sync, and cleanup.
	@server
]=]
local EnemyContext = Knit.CreateService({
	Name = "EnemyContext",
	Client = {},
	WorldService = {
		Name = "EnemyECSWorldService",
		Module = EnemyECSWorldService,
	},
	Modules = EnemyModules,
	Cache = {
		World = "_world",
		EnemyComponents = {
			Field = "_components",
			From = "EnemyComponentRegistry",
			Method = "GetComponents",
			Result = false,
		},
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_spawnConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
		},
	},
})

local EnemyBaseContext = BaseContext.new(EnemyContext)

-- [Public API]

--[=[
	@within EnemyContext
	Registers the enemy world, services, commands, and queries.
]=]
function EnemyContext:KnitInit()
	EnemyBaseContext:KnitInit()
	self._spawnConnection = nil :: any
	self._runEndedConnection = nil :: any
end

--[=[
	@within EnemyContext
	Wires the sync scheduler and run event handlers after initialization has completed.
]=]
function EnemyContext:KnitStart()
	EnemyBaseContext:KnitStart()
	EnemyBaseContext:RegisterSyncSystem("_syncService", nil, "EnemySync")

	-- Forward wave spawns into the spawn command so the context owns the creation path.
	self._spawnConnection = GameEvents.Bus:On(
		GameEvents.Events.Wave.SpawnEnemy,
		function(role: string, spawnCFrame: CFrame, waveNumber: number)
			self:_OnWaveSpawnEnemy(role, spawnCFrame, waveNumber)
		end
	)

	-- Clean up all enemies when the run ends so no stale entities survive the lifecycle boundary.
	self._runEndedConnection = GameEvents.Bus:On(GameEvents.Events.Run.RunEnded, function()
		self:_OnRunEnded()
	end)
end

-- Wraps the wave spawn event in the enemy spawn use-case and reports failures through Result logging.
function EnemyContext:_OnWaveSpawnEnemy(role: string, spawnCFrame: CFrame, waveNumber: number)
	local result = self:SpawnEnemy(role, spawnCFrame, waveNumber)
	if not result.success then
		Result.MentionError("Enemy:OnWaveSpawnEnemy", "Failed to spawn enemy", {
			Role = role,
			WaveNumber = waveNumber,
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

-- Wraps the run-ended event in the enemy cleanup use-case and reports failures through Result logging.
function EnemyContext:_OnRunEnded()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Enemy:OnRunEnded", "Failed to cleanup enemies after run ended", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

--[=[
	@within EnemyContext
	Spawns a new enemy entity and its replicated model for the supplied wave.
	@param role string -- Enemy role configured for the wave group.
	@param spawnCFrame CFrame -- World transform to spawn the enemy at.
	@param waveNumber number -- Wave that requested the spawn.
	@return Result.Result<number> -- Enemy entity id when spawn succeeds.
]=]
function EnemyContext:SpawnEnemy(role: string, spawnCFrame: CFrame, waveNumber: number): Result.Result<number>
	return Catch(function()
		return self._spawnEnemyCommand:Execute(role, spawnCFrame, waveNumber)
	end, "Enemy:SpawnEnemy")
end

--[=[
	@within EnemyContext
	Despawns an enemy entity and releases any associated model resources.
	@param entity any -- Enemy entity id to remove.
	@return Result.Result<boolean> -- Whether the despawn completed successfully.
]=]
function EnemyContext:DespawnEnemy(entity: any): Result.Result<boolean>
	return Catch(function()
		return self._despawnEnemyCommand:Execute(entity)
	end, "Enemy:DespawnEnemy")
end

--[=[
	@within EnemyContext
	Applies damage to an enemy entity and resolves death side effects when health reaches zero.
	@param entity any -- Enemy entity id to damage.
	@param amount number -- Positive damage amount to apply.
	@return Result.Result<boolean> -- Whether the damage killed the enemy.
]=]
function EnemyContext:ApplyDamage(entity: any, amount: number): Result.Result<boolean>
	return Catch(function()
		return self._applyDamageEnemyCommand:Execute(entity, amount)
	end, "Enemy:ApplyDamage")
end

--[=[
	@within EnemyContext
	Returns the current alive enemy entity list.
	@return Result.Result<{ any }> -- Live enemy entities in the enemy world.
]=]
function EnemyContext:GetAliveEnemies(): Result.Result<{ any }>
	return Catch(function()
		return self._getAliveEnemiesQuery:Execute()
	end, "Enemy:GetAliveEnemies")
end

--[=[
	@within EnemyContext
	Returns the current enemy entity count.
	@return Result.Result<number> -- Number of live enemy entities.
]=]
function EnemyContext:GetEnemyCount(): Result.Result<number>
	return Catch(function()
		return self._getEnemyCountQuery:Execute()
	end, "Enemy:GetEnemyCount")
end

--[=[
	@within EnemyContext
	Returns the authoritative enemy ECS world for other contexts that need it.
	@return Result.Result<any> -- Enemy ECS world instance.
]=]
function EnemyContext:GetWorld(): Result.Result<any>
	return Ok(self._world)
end

--[=[
	@within EnemyContext
	Returns the enemy component registry for bridge-only consumers.
	@return Result.Result<any> -- Enemy component registry.
]=]
function EnemyContext:GetComponents(): Result.Result<any>
	return Ok(self._components)
end

--[=[
	@within EnemyContext
	Returns the enemy entity factory for other server contexts that need it.
	@return Result.Result<any> -- Enemy entity factory.
]=]
function EnemyContext:GetEntityFactory(): Result.Result<any>
	return Ok(self._entityFactory)
end

--[=[
	@within EnemyContext
	Returns the enemy model factory for other server contexts that need it.
	@return Result.Result<any> -- Enemy model factory.
]=]
function EnemyContext:GetModelFactory(): Result.Result<any>
	return Ok(self._modelFactory)
end

--[=[
	@within EnemyContext
	Returns the enemy game object sync service used by other server contexts.
	@return Result.Result<any> -- Enemy game object sync service.
]=]
function EnemyContext:GetGameObjectSyncService(): Result.Result<any>
	return Ok(self._syncService)
end

--[=[
	@within EnemyContext
	Cleans up all live enemy entities and their replicated models.
	@return Result.Result<boolean> -- Whether cleanup completed successfully.
]=]
function EnemyContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupAllEnemiesCommand:Execute()
	end, "Enemy:CleanupAll")
end

function EnemyContext:_BeforeDestroy()
	-- Clear live enemies before disconnecting listeners so no later callback sees stale entities.
	local cleanupResult = self:CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Enemy:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end
end

--[=[
	@within EnemyContext
	Stops enemy event listeners and clears remaining enemies during shutdown.
]=]
function EnemyContext:Destroy()
	local destroyResult = EnemyBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Enemy:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return EnemyContext
