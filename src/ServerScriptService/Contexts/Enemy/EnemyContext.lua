--!strict

--[[
	Module: EnemyContext
	Purpose: Owns the authoritative enemy ECS world, spawn and despawn use-cases, and run-lifecycle cleanup.
	Used In System: Started by Knit on the server and called by combat, wave, and shutdown event handlers.
	High-Level Flow: Register infrastructure -> initialize ECS modules -> expose commands and queries -> clean up on run end.
	Boundaries: Owns enemy orchestration only; does not own combat targeting, wave composition, or client animation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

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
--[=[
	@class EnemyContext
	Orchestrates the authoritative enemy lane stack for spawn, model sync, and cleanup.
	@server
]=]
local EnemyContext = Knit.CreateService({
	Name = "EnemyContext",
	Client = {},
})

-- [Private Helpers]

local function _InitModule(registry: any, moduleName: string)
	local module = registry:Get(moduleName)
	if type(module) == "function" then
		return
	end

	if module.Init and type(module.Init) == "function" then
		module:Init(registry, moduleName)
	end
end

-- [Public API]

--[=[
	@within EnemyContext
	Registers the enemy registry, infrastructure services, and public use-case modules.
]=]
function EnemyContext:KnitInit()
	local registry = Registry.new("Server")
	local worldService = EnemyECSWorldService.new()

	-- Register infrastructure first so downstream modules can resolve ECS dependencies.
	registry:Register("EnemyECSWorldService", worldService, "Infrastructure")
	worldService:Init(registry, "EnemyECSWorldService")
	registry:Register("World", worldService:GetWorld())
	registry:Register("EnemyComponentRegistry", EnemyComponentRegistry.new(), "Infrastructure")
	registry:Register("EnemyEntityFactory", EnemyEntityFactory.new(), "Infrastructure")
	registry:Register("EnemyModelFactory", EnemyModelFactory.new(), "Infrastructure")
	registry:Register("EnemyGameObjectSyncService", EnemyGameObjectSyncService.new(), "Infrastructure")
	registry:Register("EnemySpawnPolicy", EnemySpawnPolicy.new(), "Domain")
	registry:Register("DespawnEnemyCommand", DespawnEnemyCommand.new(), "Application")
	registry:Register("ApplyDamageEnemyCommand", ApplyDamageEnemyCommand.new(), "Application")
	registry:Register("SpawnEnemyCommand", SpawnEnemyCommand.new(), "Application")
	registry:Register("CleanupAllEnemiesCommand", CleanupAllEnemiesCommand.new(), "Application")
	registry:Register("GetAliveEnemiesQuery", GetAliveEnemiesQuery.new(), "Application")
	registry:Register("GetEnemyCountQuery", GetEnemyCountQuery.new(), "Application")

	-- Initialize core ECS modules first so entity factory component ids are guaranteed.
	_InitModule(registry, "EnemyECSWorldService")
	_InitModule(registry, "EnemyComponentRegistry")
	_InitModule(registry, "EnemyEntityFactory")

	-- Initialize remaining modules after core ECS dependencies are ready.
	_InitModule(registry, "EnemyModelFactory")
	_InitModule(registry, "EnemyGameObjectSyncService")
	_InitModule(registry, "EnemySpawnPolicy")
	_InitModule(registry, "DespawnEnemyCommand")
	_InitModule(registry, "ApplyDamageEnemyCommand")
	_InitModule(registry, "SpawnEnemyCommand")
	_InitModule(registry, "CleanupAllEnemiesCommand")
	_InitModule(registry, "GetAliveEnemiesQuery")
	_InitModule(registry, "GetEnemyCountQuery")

	self._registry = registry
	self._world = registry:Get("World")
	self._components = registry:Get("EnemyComponentRegistry"):GetComponents()
	self._entityFactory = registry:Get("EnemyEntityFactory")
	self._modelFactory = registry:Get("EnemyModelFactory")
	self._syncService = registry:Get("EnemyGameObjectSyncService")
	self._spawnEnemyCommand = registry:Get("SpawnEnemyCommand")
	self._despawnEnemyCommand = registry:Get("DespawnEnemyCommand")
	self._applyDamageEnemyCommand = registry:Get("ApplyDamageEnemyCommand")
	self._cleanupAllEnemiesCommand = registry:Get("CleanupAllEnemiesCommand")
	self._getAliveEnemiesQuery = registry:Get("GetAliveEnemiesQuery")
	self._getEnemyCountQuery = registry:Get("GetEnemyCountQuery")
	self._spawnConnection = nil :: any
	self._runEndedConnection = nil :: any
end

--[=[
	@within EnemyContext
	Wires the sync scheduler and run event handlers after initialization has completed.
]=]
function EnemyContext:KnitStart()
	-- Sync dirty enemy entities every scheduler tick so replicated models stay current.
	ServerScheduler:RegisterSystem(function()
		self._syncService:SyncDirtyEntities()
	end, "EnemySync")

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

--[=[
	@within EnemyContext
	Stops enemy event listeners and clears remaining enemies during shutdown.
]=]
function EnemyContext:Destroy()
	-- Clear live enemies before disconnecting listeners so no later callback sees stale entities.
	local cleanupResult = self:CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Enemy:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end

	-- Disconnect run-lifecycle listeners after cleanup completes.
	if self._spawnConnection then
		self._spawnConnection:Disconnect()
	end

	if self._runEndedConnection then
		self._runEndedConnection:Disconnect()
	end
end

WrapContext(EnemyContext, "Enemy")

return EnemyContext
