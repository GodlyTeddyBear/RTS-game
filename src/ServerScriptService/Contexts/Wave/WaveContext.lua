--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local Errors = require(script.Parent.Errors)
local HandleWaveStartedCommand = require(script.Parent.Application.Commands.HandleWaveStartedCommand)
local HandleEnemyDiedCommand = require(script.Parent.Application.Commands.HandleEnemyDiedCommand)
local HandleWaveEndedCommand = require(script.Parent.Application.Commands.HandleWaveEndedCommand)
local HandleRunEndedCommand = require(script.Parent.Application.Commands.HandleRunEndedCommand)
local GetActiveEnemyCountQuery = require(script.Parent.Application.Queries.GetActiveEnemyCountQuery)
local GetCurrentWaveNumberQuery = require(script.Parent.Application.Queries.GetCurrentWaveNumberQuery)
local EndlessScalingService = require(script.Parent.Infrastructure.Services.EndlessScalingService)
local WaveCompositionService = require(script.Parent.Infrastructure.Services.WaveCompositionService)
local WaveSpawnScheduler = require(script.Parent.Infrastructure.Services.WaveSpawnScheduler)
local WaveRuntimeStateService = require(script.Parent.Infrastructure.Services.WaveRuntimeStateService)
local WaveLifecycleService = require(script.Parent.WaveDomain.Services.WaveLifecycleService)
local WaveCountingService = require(script.Parent.WaveDomain.Services.WaveCountingService)

--[=[
	@class WaveContext
	Coordinates wave lifecycle events, commands, and queries on the server.
	@server
]=]
local WaveContext = Knit.CreateService({
	Name = "WaveContext",
	Client = {},
})

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	Initializes the wave registry, commands, queries, and runtime state.
	@within WaveContext
]=]
function WaveContext:KnitInit()
	-- Register the full Wave context stack before any event can reach the handlers.
	local registry = Registry.new("Server")
	registry:Register("EndlessScalingService", EndlessScalingService.new(), "Infrastructure")
	registry:Register("WaveCompositionService", WaveCompositionService.new(), "Infrastructure")
	registry:Register("WaveSpawnScheduler", WaveSpawnScheduler.new(), "Infrastructure")
	registry:Register("WaveRuntimeStateService", WaveRuntimeStateService.new(), "Infrastructure")
	registry:Register("WaveLifecycleService", WaveLifecycleService.new(), "Domain")
	registry:Register("WaveCountingService", WaveCountingService.new(), "Domain")
	registry:Register("HandleWaveStartedCommand", HandleWaveStartedCommand.new(), "Application")
	registry:Register("HandleEnemyDiedCommand", HandleEnemyDiedCommand.new(), "Application")
	registry:Register("HandleWaveEndedCommand", HandleWaveEndedCommand.new(), "Application")
	registry:Register("HandleRunEndedCommand", HandleRunEndedCommand.new(), "Application")
	registry:Register("GetActiveEnemyCountQuery", GetActiveEnemyCountQuery.new(), "Application")
	registry:Register("GetCurrentWaveNumberQuery", GetCurrentWaveNumberQuery.new(), "Application")
	registry:InitAll()

	self._handleWaveStartedCommand = registry:Get("HandleWaveStartedCommand")
	self._handleEnemyDiedCommand = registry:Get("HandleEnemyDiedCommand")
	self._handleWaveEndedCommand = registry:Get("HandleWaveEndedCommand")
	self._handleRunEndedCommand = registry:Get("HandleRunEndedCommand")
	self._getActiveEnemyCountQuery = registry:Get("GetActiveEnemyCountQuery")
	self._getCurrentWaveNumberQuery = registry:Get("GetCurrentWaveNumberQuery")

	self._spawnCFrames = {}
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
	-- Resolve cross-context dependencies once so handlers stay lightweight.
	self._runContext = Knit.GetService("RunContext")
	self._worldContext = Knit.GetService("WorldContext")
	local spawnPointsResult = self._worldContext:GetSpawnPoints()
	if spawnPointsResult.success then
		self._spawnCFrames = spawnPointsResult.value
	else
		Result.MentionError("Wave:KnitStart", Errors.MISSING_WORLD_CONTEXT, {
			CauseType = spawnPointsResult.type,
			CauseMessage = spawnPointsResult.message,
		}, "MissingWorldContext")
		self._spawnCFrames = {}
	end

	-- Guard the scheduler input early so the event handlers can assume a valid spawn list.
	if #self._spawnCFrames == 0 then
		Result.MentionError("Wave:KnitStart", Errors.NO_SPAWN_POINTS, nil, "NoSpawnPoints")
	end

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

	-- Count down active enemies when the future enemy context reports a death.
	self._enemyDiedConnection = GameEvents.Bus:On(
		GameEvents.Events.Wave.EnemyDied,
		function(role: string, waveNumber: number, deathCFrame: CFrame)
			self:_OnWaveEnemyDied(role, waveNumber, deathCFrame)
		end
	)
end

--[=[
	Delegates a wave-start event into the application command pipeline.
	@within WaveContext
	@param waveNumber number -- The active wave number.
	@param isEndless boolean -- Whether the wave is in endless mode.
]=]
-- Bridge the run start event into the command pipeline so the context stays a thin boundary.
function WaveContext:_OnRunWaveStarted(waveNumber: number, isEndless: boolean)
	Catch(function()
		Ensure(self._runContext, "MissingDependency", Errors.MISSING_RUN_CONTEXT)
		Try(self._handleWaveStartedCommand:Execute(waveNumber, isEndless, self._spawnCFrames, self._runContext))
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
	Catch(function()
		Try(self._handleRunEndedCommand:Execute())
		return Ok(nil)
	end, "Wave:Destroy")

	if self._runWaveStartedConnection then
		self._runWaveStartedConnection:Disconnect()
	end
	if self._runWaveEndedConnection then
		self._runWaveEndedConnection:Disconnect()
	end
	if self._runEndedConnection then
		self._runEndedConnection:Disconnect()
	end
	if self._enemyDiedConnection then
		self._enemyDiedConnection:Disconnect()
	end
end

WrapContext(WaveContext, "Wave")

return WaveContext
