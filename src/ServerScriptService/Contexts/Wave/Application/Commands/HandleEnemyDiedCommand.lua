--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Try = Result.Try
local Ensure = Result.Ensure

--[=[
	@class HandleEnemyDiedCommand
	Consumes enemy death events and clears the wave when the session is exhausted.
	@server
]=]
local HandleEnemyDiedCommand = {}
HandleEnemyDiedCommand.__index = HandleEnemyDiedCommand

--[=[
	Creates a new enemy-death handler command.
	@within HandleEnemyDiedCommand
	@return HandleEnemyDiedCommand -- The new command instance.
]=]
function HandleEnemyDiedCommand.new()
	return setmetatable({}, HandleEnemyDiedCommand)
end

--[=[
	Wires the scheduler, runtime state, lifecycle, and counting dependencies.
	@within HandleEnemyDiedCommand
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function HandleEnemyDiedCommand:Init(registry: any, _name: string)
	self._scheduler = registry:Get("WaveSpawnScheduler")
	self._state = registry:Get("WaveRuntimeStateService")
	self._lifecycle = registry:Get("WaveLifecycleService")
	self._counting = registry:Get("WaveCountingService")
end

-- Returns true when the current state can be closed out after a death update.
function HandleEnemyDiedCommand:_TryCompleteWave(runContext: any): Result.Result<boolean>
	local state = self._state:GetStateReadOnly()
	if not self._lifecycle:ShouldCompleteWave(state) then
		return Ok(false)
	end

	self._scheduler:CancelAll()
	self._state:SetState(self._lifecycle:MarkWaveCompleted(state))

	Ensure(runContext, "MissingRunContext", Errors.MISSING_RUN_CONTEXT)
	Try(runContext:NotifyWaveCleared())

	return Ok(true)
end

--[=[
	Registers a death for the active wave and resolves the run if the last enemy died.
	@within HandleEnemyDiedCommand
	@param role string -- The enemy role reported by `EnemyContext`.
	@param waveNumber number -- The wave number attached to the death event.
	@param deathCFrame CFrame -- The reported death position for future drop systems.
	@param runContext any -- The `RunContext` service used to notify completion.
	@return Result.Result<boolean> -- `true` when the command consumed the death.
]=]
function HandleEnemyDiedCommand:Execute(
	role: string,
	waveNumber: number,
	_deathCFrame: CFrame,
	runContext: any
): Result.Result<boolean>
	-- Ignore deaths that arrive before a wave session exists.
	local state = self._state:GetStateReadOnly()
	if not self._lifecycle:IsWaveActive(state) then
		Result.MentionEvent("Wave:HandleEnemyDiedCommand", Errors.INVALID_ENEMY_DIED, {
			Role = role,
			WaveNumber = waveNumber,
		})
		return Ok(false)
	end

	-- Stale deaths from prior waves should not mutate the live session.
	if not self._lifecycle:IsCurrentWave(state, waveNumber) then
		return Ok(false)
	end

	-- Update counters before checking completion so this death participates in the final boundary.
	local nextState = self._counting:ApplyEnemyDied(state)
	self._state:SetState(nextState)

	Result.MentionEvent("Wave:HandleEnemyDiedCommand", "Enemy death registered", {
		Role = role,
		WaveNumber = waveNumber,
		PendingSpawns = nextState.pendingSpawnCount,
		ActiveEnemies = nextState.activeEnemyCount,
	})

	-- Resolve the wave if this was the last remaining enemy.
	local completedResult = self:_TryCompleteWave(runContext)
	if not completedResult.success then
		return completedResult
	end

	return Ok(completedResult.value)
end

return HandleEnemyDiedCommand
