--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local Signal = require(ReplicatedStorage.Packages.Signal)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Err = Result.Err

type RunState = RunTypes.RunState
local LEGAL_TRANSITIONS: { [RunState]: { [RunState]: boolean } } = {
	Idle = {
		Prep = true,
	},
	Prep = {
		Wave = true,
		RunEnd = true,
	},
	Wave = {
		Resolution = true,
		RunEnd = true,
	},
	Resolution = {
		Prep = true,
		Climax = true,
		RunEnd = true,
	},
	Climax = {
		Endless = true,
		RunEnd = true,
	},
	Endless = {
		Resolution = true,
		RunEnd = true,
	},
	RunEnd = {
		Prep = true,
		Idle = true,
	},
}

--[=[
	@class RunStateMachine
	Tracks the authoritative run phase and exposes transition validation.
	@server
]=]
local RunStateMachine = {}
RunStateMachine.__index = RunStateMachine

--[=[
	@prop StateChanged Signal
	@within RunStateMachine
	Fires whenever the run state advances.
]=]

--[=[
	Creates a new state machine with the `Idle` state.
	@within RunStateMachine
	@return RunStateMachine -- The new state machine instance.
]=]
function RunStateMachine.new()
	local self = setmetatable({}, RunStateMachine)
	-- Seed the authoritative run snapshot before any application command mutates it.
	self._state = "Idle" :: RunState
	self._waveNumber = 0
	-- Expose transition listeners so RunContext can bridge state changes to sync.
	self.StateChanged = Signal.new()
	return self
end

--[=[
	Initializes the state machine for registry ownership.
	@within RunStateMachine
	@param registry any -- The module registry that owns this service.
	@param name string -- The registered module name.
]=]
function RunStateMachine:Init(_registry: any, _name: string)
end

--[=[
	Returns the current authoritative run state.
	@within RunStateMachine
	@return RunState -- The current state.
]=]
function RunStateMachine:GetState(): RunState
	return self._state
end

--[=[
	Returns the current authoritative wave number.
	@within RunStateMachine
	@return number -- The current wave number.
]=]
function RunStateMachine:GetWaveNumber(): number
	return self._waveNumber
end

--[=[
	Resets the authoritative wave number.
	@within RunStateMachine
]=]
function RunStateMachine:ResetWaveNumber()
	self._waveNumber = 0
end

--[=[
	Increments and returns the authoritative wave number.
	@within RunStateMachine
	@return number -- The incremented wave number.
]=]
function RunStateMachine:IncrementWaveNumber(): number
	self._waveNumber += 1
	return self._waveNumber
end

--[=[
	Advances the run state when the transition is legal.
	@within RunStateMachine
	@param newState RunState -- State to enter.
	@return Result<RunState> -- The accepted state or an illegal-transition error.
]=]
function RunStateMachine:Transition(newState: RunState): Result.Result<RunState>
	-- Validate the requested edge before mutating shared state.
	local previousState = self._state
	local legalTargets = LEGAL_TRANSITIONS[previousState]
	if not legalTargets[newState] then
		return Err("IllegalTransition", Errors.ILLEGAL_TRANSITION, {
			From = previousState,
			To = newState,
		})
	end

	self._state = newState
	self.StateChanged:Fire(newState, previousState)
	return Ok(newState)
end

--[=[
	Releases the `StateChanged` signal when the service is destroyed.
	@within RunStateMachine
]=]
function RunStateMachine:Destroy()
	self.StateChanged:Destroy()
end

return RunStateMachine
