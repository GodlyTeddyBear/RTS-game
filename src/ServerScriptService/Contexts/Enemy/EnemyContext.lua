--!strict

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
local CleanupAllEnemiesCommand = require(script.Parent.Application.Commands.CleanupAllEnemies)
local GetAliveEnemiesQuery = require(script.Parent.Application.Queries.GetAliveEnemiesQuery)
local GetEnemyCountQuery = require(script.Parent.Application.Queries.GetEnemyCountQuery)

local Catch = Result.Catch

--[=[
	@class EnemyContext
	Owns the authoritative enemy lane stack for spawn, model sync, and cleanup.
	@server
]=]
local EnemyContext = Knit.CreateService({
	Name = "EnemyContext",
	Client = {},
})

function EnemyContext:KnitInit()
	local registry = Registry.new("Server")

	registry:Register("EnemyECSWorldService", EnemyECSWorldService.new(), "Infrastructure")
	registry:Register("World", registry:Get("EnemyECSWorldService"):GetWorld())
	registry:Register("EnemyComponentRegistry", EnemyComponentRegistry.new(), "Infrastructure")
	registry:Register("EnemyEntityFactory", EnemyEntityFactory.new(), "Infrastructure")
	registry:Register("EnemyModelFactory", EnemyModelFactory.new(), "Infrastructure")
	registry:Register("EnemyGameObjectSyncService", EnemyGameObjectSyncService.new(), "Infrastructure")
	registry:Register("EnemySpawnPolicy", EnemySpawnPolicy.new(), "Domain")
	registry:Register("DespawnEnemyCommand", DespawnEnemyCommand.new(), "Application")
	registry:Register("SpawnEnemyCommand", SpawnEnemyCommand.new(), "Application")
	registry:Register("CleanupAllEnemiesCommand", CleanupAllEnemiesCommand.new(), "Application")
	registry:Register("GetAliveEnemiesQuery", GetAliveEnemiesQuery.new(), "Application")
	registry:Register("GetEnemyCountQuery", GetEnemyCountQuery.new(), "Application")

	registry:Get("EnemyECSWorldService"):Init(registry, "EnemyECSWorldService")
	registry:Get("EnemyComponentRegistry"):Init(registry, "EnemyComponentRegistry")
	registry:Get("EnemyEntityFactory"):Init(registry, "EnemyEntityFactory")
	registry:Get("EnemyModelFactory"):Init(registry, "EnemyModelFactory")
	registry:Get("EnemyGameObjectSyncService"):Init(registry, "EnemyGameObjectSyncService")
	registry:Get("DespawnEnemyCommand"):Init(registry, "DespawnEnemyCommand")
	registry:Get("SpawnEnemyCommand"):Init(registry, "SpawnEnemyCommand")
	registry:Get("CleanupAllEnemiesCommand"):Init(registry, "CleanupAllEnemiesCommand")
	registry:Get("GetAliveEnemiesQuery"):Init(registry, "GetAliveEnemiesQuery")
	registry:Get("GetEnemyCountQuery"):Init(registry, "GetEnemyCountQuery")

	self._registry = registry
	self._syncService = registry:Get("EnemyGameObjectSyncService")
	self._spawnEnemyCommand = registry:Get("SpawnEnemyCommand")
	self._despawnEnemyCommand = registry:Get("DespawnEnemyCommand")
	self._cleanupAllEnemiesCommand = registry:Get("CleanupAllEnemiesCommand")
	self._getAliveEnemiesQuery = registry:Get("GetAliveEnemiesQuery")
	self._getEnemyCountQuery = registry:Get("GetEnemyCountQuery")
	self._spawnConnection = nil :: any
	self._runEndedConnection = nil :: any
end

function EnemyContext:KnitStart()
	ServerScheduler:RegisterSystem(function()
		self._syncService:SyncDirtyEntities()
	end, "EnemySync")

	self._spawnConnection = GameEvents.Bus:On(GameEvents.Events.Wave.SpawnEnemy, function(role: string, spawnCFrame: CFrame, waveNumber: number)
		self:_OnWaveSpawnEnemy(role, spawnCFrame, waveNumber)
	end)

	self._runEndedConnection = GameEvents.Bus:On(GameEvents.Events.Run.RunEnded, function()
		self:_OnRunEnded()
	end)
end

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

function EnemyContext:_OnRunEnded()
	local result = self:CleanupAll()
	if not result.success then
		Result.MentionError("Enemy:OnRunEnded", "Failed to cleanup enemies after run ended", {
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function EnemyContext:SpawnEnemy(role: string, spawnCFrame: CFrame, waveNumber: number): Result.Result<number>
	return Catch(function()
		return self._spawnEnemyCommand:Execute(role, spawnCFrame, waveNumber)
	end, "Enemy:SpawnEnemy")
end

function EnemyContext:DespawnEnemy(entity: any): Result.Result<boolean>
	return Catch(function()
		return self._despawnEnemyCommand:Execute(entity)
	end, "Enemy:DespawnEnemy")
end

function EnemyContext:GetAliveEnemies(): Result.Result<{ any }>
	return Catch(function()
		return self._getAliveEnemiesQuery:Execute()
	end, "Enemy:GetAliveEnemies")
end

function EnemyContext:GetEnemyCount(): Result.Result<number>
	return Catch(function()
		return self._getEnemyCountQuery:Execute()
	end, "Enemy:GetEnemyCount")
end

function EnemyContext:CleanupAll(): Result.Result<boolean>
	return Catch(function()
		return self._cleanupAllEnemiesCommand:Execute()
	end, "Enemy:CleanupAll")
end

function EnemyContext:Destroy()
	local cleanupResult = self:CleanupAll()
	if not cleanupResult.success then
		Result.MentionError("Enemy:Destroy", "Cleanup failed during destroy", {
			CauseType = cleanupResult.type,
			CauseMessage = cleanupResult.message,
		}, cleanupResult.type)
	end

	if self._spawnConnection then
		self._spawnConnection:Disconnect()
	end

	if self._runEndedConnection then
		self._runEndedConnection:Disconnect()
	end
end

WrapContext(EnemyContext, "Enemy")

return EnemyContext
