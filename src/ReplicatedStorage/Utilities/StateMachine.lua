--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)

local DEFAULT_ERROR_TYPE = "IllegalTransition"
local DEFAULT_ERROR_MESSAGE = "State transition is not allowed"

type StateChangedConnection = {
	Disconnect: (self: StateChangedConnection) -> (),
}

type StateChangedSignal<TState> = {
	Connect: (
		self: StateChangedSignal<TState>,
		callback: (newState: TState, previousState: TState) -> ()
	) -> StateChangedConnection,
	Once: (
		self: StateChangedSignal<TState>,
		callback: (newState: TState, previousState: TState) -> ()
	) -> StateChangedConnection,
	Fire: (self: StateChangedSignal<TState>, newState: TState, previousState: TState) -> (),
	Wait: (self: StateChangedSignal<TState>) -> (TState, TState),
	DisconnectAll: (self: StateChangedSignal<TState>) -> (),
}

--[=[
	@class StateMachine
	Reusable finite-state-machine utility with Result-based transition validation.
	@server
	@client
]=]
local StateMachine = {}
StateMachine.__index = StateMachine

--[=[
	@interface TStateMachineConfig
	@within StateMachine
	.InitialState any -- State assigned when the machine is created.
	.Transitions table -- Map of source states to legal target states.
	.ErrorType string? -- Optional Result error type for rejected transitions.
	.ErrorMessage string? -- Optional Result message for rejected transitions.
	.ErrorDataBuilder function? -- Optional function that builds Result error data from `(fromState, toState)`.
]=]
export type TStateMachineConfig<TState> = {
	InitialState: TState,
	Transitions: { [any]: { [any]: boolean } },
	ErrorType: string?,
	ErrorMessage: string?,
	ErrorDataBuilder: ((fromState: TState, toState: TState) -> { [string]: any })?,
}

--[=[
	@interface TStateMachine
	@within StateMachine
	.StateChanged any -- Signal fired after accepted transitions with `(newState, previousState)`.
	.GetState function -- Returns the current state.
	.CanTransition function -- Returns whether a transition is legal from the current state.
	.Transition function -- Attempts a transition and returns a Result.
	.Destroy function -- Releases the StateChanged signal.
]=]
export type TStateMachine<TState> = {
	StateChanged: StateChangedSignal<TState>,
	_state: TState,
	_transitions: { [any]: { [any]: boolean } },
	_errorType: string,
	_errorMessage: string,
	_errorDataBuilder: ((fromState: TState, toState: TState) -> { [string]: any })?,

	GetState: (self: TStateMachine<TState>) -> TState,
	CanTransition: (self: TStateMachine<TState>, newState: TState) -> boolean,
	Transition: (self: TStateMachine<TState>, newState: TState) -> Result.Result<TState>,
	Destroy: (self: TStateMachine<TState>) -> (),
	_BuildTransitionErrorData: (self: TStateMachine<TState>, fromState: TState, toState: TState) -> { [string]: any },
}

--[=[
	Creates a state machine from an initial state and legal transition map.
	@within StateMachine
	@param config TStateMachineConfig -- State machine configuration.
	@return TStateMachine -- The new state machine instance.
	@error string -- Thrown if required config fields are missing.
]=]
function StateMachine.new<TState>(config: TStateMachineConfig<TState>): TStateMachine<TState>
	assert(config.InitialState ~= nil, "StateMachine requires InitialState")
	assert(config.Transitions ~= nil, "StateMachine requires Transitions")

	local self = setmetatable({}, StateMachine) :: any
	self._state = config.InitialState
	self._transitions = config.Transitions
	self._errorType = config.ErrorType or DEFAULT_ERROR_TYPE
	self._errorMessage = config.ErrorMessage or DEFAULT_ERROR_MESSAGE
	self._errorDataBuilder = config.ErrorDataBuilder
	self.StateChanged = GoodSignal.new()

	return self
end

--[=[
	Returns the current state.
	@within StateMachine
	@return any -- The current state.
]=]
function StateMachine:GetState<TState>(): TState
	return (self :: any)._state
end

--[=[
	Returns whether the requested state is legal from the current state.
	@within StateMachine
	@param newState any -- Target state to evaluate.
	@return boolean -- `true` when the transition is legal.
]=]
function StateMachine:CanTransition<TState>(newState: TState): boolean
	local machine = self :: TStateMachine<TState>
	local legalTargets = machine._transitions[machine._state]
	return legalTargets ~= nil and legalTargets[newState] == true
end

--[=[
	Attempts to move the machine into a new state.
	@within StateMachine
	@param newState any -- Target state to enter.
	@return Result.Result -- `Ok(newState)` when accepted, or `Err` when rejected.
]=]
function StateMachine:Transition<TState>(newState: TState): Result.Result<TState>
	local machine = self :: TStateMachine<TState>
	local previousState = machine._state

	if not machine:CanTransition(newState) then
		return Result.Err(
			machine._errorType,
			machine._errorMessage,
			machine:_BuildTransitionErrorData(previousState, newState)
		)
	end

	machine._state = newState
	machine.StateChanged:Fire(newState, previousState)

	return Result.Ok(newState)
end

--[=[
	Releases the state-change signal.
	@within StateMachine
]=]
function StateMachine:Destroy<TState>()
	local machine = self :: TStateMachine<TState>
	machine.StateChanged:DisconnectAll()
end

function StateMachine:_BuildTransitionErrorData<TState>(fromState: TState, toState: TState): { [string]: any }
	local machine = self :: TStateMachine<TState>
	local errorDataBuilder = machine._errorDataBuilder
	if errorDataBuilder then
		return errorDataBuilder(fromState, toState)
	end

	return {
		From = fromState,
		To = toState,
	}
end

return table.freeze(StateMachine)
