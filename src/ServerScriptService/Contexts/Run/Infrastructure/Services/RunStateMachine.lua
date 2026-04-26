--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)

local Errors = require(script.Parent.Parent.Parent.Errors)

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
	self._machine = StateMachine.new({
		InitialState = "Idle" :: RunState,
		Transitions = LEGAL_TRANSITIONS,
		ErrorType = "IllegalTransition",
		ErrorMessage = Errors.ILLEGAL_TRANSITION,
	})
	self._waveNumber = 0
	-- Expose transition listeners so RunContext can bridge state changes to sync.
	self.StateChanged = self._machine.StateChanged
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
	return self._machine:GetState()
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
	return self._machine:Transition(newState)
end

--[=[
	Releases the `StateChanged` signal when the service is destroyed.
	@within RunStateMachine
]=]
function RunStateMachine:Destroy()
	self._machine:Destroy()
end

return RunStateMachine
