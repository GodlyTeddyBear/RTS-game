--!strict

--[[
    Module: WaveContext
    Purpose: Coordinates wave lifecycle commands, queries, and event bridges on the server.
    Used In System: Started by Knit as the server boundary for wave-start, wave-end, and enemy-death events.
    Boundaries: Owns orchestration only; does not own wave composition, countdown math, or enemy spawning.
]]

-- [Dependencies]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

local Errors = require(script.Parent.Errors)
local WaveECSWorldService = require(script.Parent.Infrastructure.ECS.WaveECSWorldService)
local WaveComponentRegistry = require(script.Parent.Infrastructure.ECS.WaveComponentRegistry)
local WaveEntityFactory = require(script.Parent.Infrastructure.ECS.WaveEntityFactory)
local EndlessScalingService = require(script.Parent.Infrastructure.Services.EndlessScalingService)
local WaveCompositionService = require(script.Parent.Infrastructure.Services.WaveCompositionService)
local WaveSpawnScheduler = require(script.Parent.Infrastructure.Services.WaveSpawnScheduler)
local WaveLifecycleService = require(script.Parent.WaveDomain.Services.WaveLifecycleService)
local WaveCountingService = require(script.Parent.WaveDomain.Services.WaveCountingService)
local HandleWaveStartedCommand = require(script.Parent.Application.Commands.HandleWaveStartedCommand)
local HandleEnemyDiedCommand = require(script.Parent.Application.Commands.HandleEnemyDiedCommand)
local HandleWaveEndedCommand = require(script.Parent.Application.Commands.HandleWaveEndedCommand)
local HandleRunEndedCommand = require(script.Parent.Application.Commands.HandleRunEndedCommand)
local GetActiveEnemyCountQuery = require(script.Parent.Application.Queries.GetActiveEnemyCountQuery)
local GetCurrentWaveNumberQuery = require(script.Parent.Application.Queries.GetCurrentWaveNumberQuery)

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "WaveComponentRegistry",
		Module = WaveComponentRegistry,
	},
	{
		Name = "WaveEntityFactory",
		Module = WaveEntityFactory,
	},
	{
		Name = "EndlessScalingService",
		Module = EndlessScalingService,
	},
	{
		Name = "WaveCompositionService",
		Module = WaveCompositionService,
	},
	{
		Name = "WaveSpawnScheduler",
		Module = WaveSpawnScheduler,
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "WaveLifecycleService",
		Module = WaveLifecycleService,
	},
	{
		Name = "WaveCountingService",
		Module = WaveCountingService,
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "HandleWaveStartedCommand",
		Module = HandleWaveStartedCommand,
		CacheAs = "_handleWaveStartedCommand",
	},
	{
		Name = "HandleEnemyDiedCommand",
		Module = HandleEnemyDiedCommand,
		CacheAs = "_handleEnemyDiedCommand",
	},
	{
		Name = "HandleWaveEndedCommand",
		Module = HandleWaveEndedCommand,
		CacheAs = "_handleWaveEndedCommand",
	},
	{
		Name = "HandleRunEndedCommand",
		Module = HandleRunEndedCommand,
		CacheAs = "_handleRunEndedCommand",
	},
	{
		Name = "GetActiveEnemyCountQuery",
		Module = GetActiveEnemyCountQuery,
		CacheAs = "_getActiveEnemyCountQuery",
	},
	{
		Name = "GetCurrentWaveNumberQuery",
		Module = GetCurrentWaveNumberQuery,
		CacheAs = "_getCurrentWaveNumberQuery",
	},
}

local WaveModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

--[=[
	@class WaveContext
	Coordinates wave lifecycle events, commands, and queries on the server.
	@server
]=]
local WaveContext = Knit.CreateService({
	Name = "WaveContext",
	Client = {},
	WorldService = {
		Name = "WaveECSWorldService",
		Module = WaveECSWorldService,
	},
	Modules = WaveModules,
	ExternalServices = {
		{ Name = "RunContext", CacheAs = "_runContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runWaveStartedConnection", Method = "Disconnect" },
			{ Field = "_runWaveEndedConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_enemyDiedConnection", Method = "Disconnect" },
		},
	},
})

local WaveBaseContext = BaseContext.new(WaveContext)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure
type SpawnArea = WorldTypes.SpawnArea

-- [Initialization]

--[=[
	Initializes the wave registry, commands, queries, and runtime state.
	@within WaveContext
]=]
function WaveContext:KnitInit()
	WaveBaseContext:KnitInit()

	-- Prepare the runtime caches and listener slots before subscriptions begin.
	self._spawnAreas = {} :: { SpawnArea }
	self._runContext = nil :: any
	self._worldContext = nil :: any

	self._runWaveStartedConnection = nil :: any
	self._runWaveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._enemyDiedConnection = nil :: any
end

--[=[
	Subscribes to run and enemy wave events after the world context is available.
	@within WaveContext
]=]
function WaveContext:KnitStart()
	WaveBaseContext:KnitStart()

	-- Bridge run transitions into wave-start handling.
	self._runWaveStartedConnection = GameEvents.Bus:On(GameEvents.Events.Run.WaveStarted, function(waveNumber: number, isEndless: boolean)
		self:_OnRunWaveStarted(waveNumber, isEndless)
	end)

	self._runWaveEndedConnection = GameEvents.Bus:On(GameEvents.Events.Run.WaveEnded, function(waveNumber: number)
		self:_OnRunWaveEnded(waveNumber)
	end)

	-- Bridge run termination into wave cleanup.
	self._runEndedConnection = GameEvents.Bus:On(GameEvents.Events.Run.RunEnded, function()
		self:_OnRunEnded()
	end)

	-- Count down active enemies when enemy context reports a death.
	self._enemyDiedConnection = GameEvents.Bus:On(
		GameEvents.Events.Wave.EnemyDied,
		function(role: string, waveNumber: number, deathCFrame: CFrame)
			self:_OnWaveEnemyDied(role, waveNumber, deathCFrame)
		end
	)
end

function WaveContext:_RefreshSpawnAreas(): boolean
	if not self._worldContext then
		self._spawnAreas = {}
		return false
	end

	local spawnAreasResult = self._worldContext:GetSpawnAreas()
	if not spawnAreasResult.success then
		Result.MentionError("Wave:RefreshSpawnAreas", Errors.NO_SPAWN_AREAS, {
			CauseType = spawnAreasResult.type,
			CauseMessage = spawnAreasResult.message,
		}, "NoSpawnAreas")
		self._spawnAreas = {}
		return false
	end

	self._spawnAreas = spawnAreasResult.value
	return #self._spawnAreas > 0
end

-- [Private Handlers]

--[=[
	Delegates a wave-start event into the application command pipeline.
	@within WaveContext
	@param waveNumber number -- The active wave number.
	@param isEndless boolean -- Whether the wave is in endless mode.
]=]
function WaveContext:_OnRunWaveStarted(waveNumber: number, isEndless: boolean)
	Catch(function()
		Ensure(self._runContext, "MissingDependency", Errors.MISSING_RUN_CONTEXT)
		Ensure(self:_RefreshSpawnAreas(), "NoSpawnAreas", Errors.NO_SPAWN_AREAS)
		Try(self._handleWaveStartedCommand:Execute(waveNumber, isEndless, self._spawnAreas, self._runContext))
		return Ok(nil)
	end, "Wave:OnRunWaveStarted")
end

-- Bridge enemy death events into the command pipeline so counter updates stay centralized.
function WaveContext:_OnWaveEnemyDied(role: string, waveNumber: number, deathCFrame: CFrame)
	Catch(function()
		Ensure(self._runContext, "MissingDependency", Errors.MISSING_RUN_CONTEXT)
		Try(self._handleEnemyDiedCommand:Execute(role, waveNumber, deathCFrame, self._runContext))
		return Ok(nil)
	end, "Wave:OnWaveEnemyDied")
end

-- Bridge the wave-ended event into the command pipeline so cleanup stays centralized.
function WaveContext:_OnRunWaveEnded(waveNumber: number)
	Catch(function()
		Try(self._handleWaveEndedCommand:Execute(waveNumber))
		return Ok(nil)
	end, "Wave:OnRunWaveEnded")
end

-- Reset the wave session when the run ends so no stale callbacks survive the lifecycle boundary.
function WaveContext:_OnRunEnded()
	Catch(function()
		Try(self._handleRunEndedCommand:Execute())
		return Ok(nil)
	end, "Wave:OnRunEnded")
end

function WaveContext:_BeforeDestroy()
	Catch(function()
		if self._handleRunEndedCommand then
			Try(self._handleRunEndedCommand:Execute())
		end
		return Ok(nil)
	end, "Wave:Destroy")
end

-- [Public API]

--[=[
	Returns the number of active enemies currently tracked for the wave.
	@within WaveContext
	@return Result.Result<number> -- The current active enemy count wrapped in `Result`.
]=]
function WaveContext:GetActiveEnemyCount(): Result.Result<number>
	return Catch(function()
		return Ok(self._getActiveEnemyCountQuery:Execute())
	end, "Wave:GetActiveEnemyCount")
end

--[=[
	Returns the current wave number tracked by the context.
	@within WaveContext
	@return Result.Result<number> -- The active wave number wrapped in `Result`.
]=]
function WaveContext:GetCurrentWaveNumber(): Result.Result<number>
	return Catch(function()
		return Ok(self._getCurrentWaveNumberQuery:Execute())
	end, "Wave:GetCurrentWaveNumber")
end

--[=[
	Cancels pending wave work and disconnects all event listeners.
	@within WaveContext
]=]
function WaveContext:Destroy()
	local destroyResult = WaveBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Wave:Destroy", Errors.TEARDOWN_FAILED, {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return WaveContext
