--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local RunConfig = require(ReplicatedStorage.Contexts.Run.Config.RunConfig)

local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class HandleWaveStartedCommand
	Starts a wave session, schedules spawns, and updates runtime state.
	@server
]=]
local HandleWaveStartedCommand = {}
HandleWaveStartedCommand.__index = HandleWaveStartedCommand

--[=[
	Creates a new wave-start handler command.
	@within HandleWaveStartedCommand
	@return HandleWaveStartedCommand -- The new command instance.
]=]
function HandleWaveStartedCommand.new()
	return setmetatable({}, HandleWaveStartedCommand)
end

--[=[
	Wires the scheduler, composition, and runtime state dependencies.
	@within HandleWaveStartedCommand
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function HandleWaveStartedCommand:Init(registry: any, _name: string)
	self._scheduler = registry:Get("WaveSpawnScheduler")
	self._composition = registry:Get("WaveCompositionService")
	self._state = registry:Get("WaveRuntimeStateService")
	self._lifecycle = registry:Get("WaveLifecycleService")
	self._counting = registry:Get("WaveCountingService")
	self._scaling = registry:Get("EndlessScalingService")
end

-- Returns true when the wave can finish immediately after state mutation.
function HandleWaveStartedCommand:_TryCompleteWave(runContext: any): Result.Result<boolean>
	local state = self._state:GetStateReadOnly()
	if not self._lifecycle:ShouldCompleteWave(state) then
		return Ok(false)
	end

	self._scheduler:CancelAll()
	self._state:SetState(self._lifecycle:MarkWaveCompleted(state))

	Try(runContext:NotifyWaveCleared())

	return Ok(true)
end

--[=[
	Starts the wave, schedules all enemy spawns, and completes immediately if the composition is empty.
	@within HandleWaveStartedCommand
	@param waveNumber number -- The current wave number.
	@param isEndless boolean -- Whether the wave is part of endless mode.
	@param spawnCFrames { CFrame } -- Cached spawn points from `WorldContext`.
	@param runContext any -- The `RunContext` service used to notify early completion.
	@return Result.Result<nil> -- `Ok(nil)` when the wave start is accepted.
	@error string -- Throws when inputs are invalid or `NotifyWaveCleared` is rejected.
]=]
function HandleWaveStartedCommand:Execute(
	waveNumber: number,
	isEndless: boolean,
	spawnCFrames: { CFrame },
	runContext: any
): Result.Result<nil>
	-- Validate the wave request before touching state so bad inputs fail fast.
	Ensure(waveNumber > 0, "InvalidWaveNumber", Errors.INVALID_WAVE_NUMBER)
	Ensure(#spawnCFrames > 0, "NoSpawnPoints", Errors.NO_SPAWN_POINTS)

	-- Reset any stale session if a previous wave was still marked active.
	local currentState = self._state:GetStateReadOnly()
	if self._lifecycle:IsWaveActive(currentState) then
		self._scheduler:CancelAll()
		self._state:SetState(self._lifecycle:ResetState())
		Result.MentionEvent("Wave:HandleWaveStartedCommand", Errors.WAVE_ALREADY_ACTIVE, {
			PreviousWave = currentState.currentWaveNumber,
			NextWave = waveNumber,
			})
	end

	-- Resolve the final composition after endless scaling is applied.
	local endlessWaveIndex = if isEndless
		then self._scaling:GetEndlessWaveIndex(waveNumber, RunConfig.CLIMAX_WAVE)
		else 0

	local composition = Try(self._composition:BuildWave(waveNumber, isEndless, endlessWaveIndex))
	-- Seed the wave session before scheduling so downstream callbacks can read authoritative counts.
	local plannedSpawns = self._counting:GetPlannedSpawnCount(composition)
	self._state:SetState(self._lifecycle:StartWaveSession(waveNumber, plannedSpawns))

	-- Schedule all enemy spawns and advance the runtime counters as each spawn activates.
	self._scheduler:Schedule(composition, spawnCFrames, waveNumber, function()
		local latestState = self._state:GetStateReadOnly()
		if not self._lifecycle:IsCurrentWave(latestState, waveNumber) then
			return
		end

		self._state:SetState(self._counting:ApplySpawnActivated(latestState))
	end)

	-- If the composition is empty, the wave can resolve immediately after state setup.
	Try(self:_TryCompleteWave(runContext))

	return Ok(nil)
end

return HandleWaveStartedCommand
