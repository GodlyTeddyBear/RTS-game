--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)

local DEFAULT_ERROR_TYPE = "IllegalTransition"
local DEFAULT_ERROR_MESSAGE = "State transition is not allowed"
local DESTROYED_ERROR_TYPE = "StateMachineDestroyed"
local DESTROYED_ERROR_MESSAGE = "State machine has been destroyed"
local TRANSITION_IN_PROGRESS_ERROR_TYPE = "TransitionInProgress"
local TRANSITION_IN_PROGRESS_ERROR_MESSAGE = "State transition is already in progress"
local UNKNOWN_STATE_ERROR_TYPE = "UnknownState"
local UNKNOWN_STATE_ERROR_MESSAGE = "Target state is not registered"
local INVALID_TRANSITIONS_ERROR_MESSAGE = "StateMachine requires transition map tables"
local INVALID_TRANSITION_ENTRY_ERROR_MESSAGE = "StateMachine transition entries must be `true` or a transition definition table"

type StateChangedConnection = {
	Disconnect: (self: StateChangedConnection) -> (),
}

type RuntimeRegistrationConnection = {
	Disconnect: (self: RuntimeRegistrationConnection) -> (),
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

type TTransitionErrorData = { [string]: any }

type TTransitionGuard<TState> = (fromState: TState, toState: TState) -> Result.Err?
type TTransitionAction<TState> = (fromState: TState, toState: TState) -> ()
type TStateEnterHook<TState> = (newState: TState, previousState: TState) -> ()
type TStateExitHook<TState> = (previousState: TState, nextState: TState) -> ()

type TTransitionDefinition<TState> = {
	Guard: TTransitionGuard<TState>?,
	Action: TTransitionAction<TState>?,
}

type TTransitionEntry<TState> = boolean | TTransitionDefinition<TState>
type TTransitionMap<TState> = { [any]: { [any]: TTransitionEntry<TState> } }
type TStateHookMap<TState> = {
	[any]: {
		OnEnter: TStateEnterHook<TState>?,
		OnExit: TStateExitHook<TState>?,
	},
}

type TStateHookRegistration<TCallback> = {
	Connected: boolean,
	Callback: TCallback,
}

type TTransitionRuntimeRegistrations<TState> = {
	Guards: { TStateHookRegistration<TTransitionGuard<TState>> },
	Actions: { TStateHookRegistration<TTransitionAction<TState>> },
}

type TTransitionRuntimeRegistry<TState> = {
	[any]: {
		[any]: TTransitionRuntimeRegistrations<TState>,
	},
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
	.StateHooks table? -- Optional lifecycle hooks keyed by state.
	.ErrorType string? -- Optional Result error type for rejected transitions.
	.ErrorMessage string? -- Optional Result message for rejected transitions.
	.ErrorDataBuilder function? -- Optional function that builds Result error data from `(fromState, toState)`.
]=]
export type TStateMachineConfig<TState> = {
	InitialState: TState,
	Transitions: TTransitionMap<TState>,
	StateHooks: TStateHookMap<TState>?,
	ErrorType: string?,
	ErrorMessage: string?,
	ErrorDataBuilder: ((fromState: TState, toState: TState) -> TTransitionErrorData)?,
}

export type TStateMachineTransitionDefinition<TState> = TTransitionDefinition<TState>
export type TStateMachineTransitionMap<TState> = TTransitionMap<TState>
export type TStateMachineStateHooks<TState> = TStateHookMap<TState>
export type TStateMachineRegistrationConnection = RuntimeRegistrationConnection

--[=[
	@interface TStateMachine
	@within StateMachine
	.StateChanged any -- Signal fired after accepted transitions with `(newState, previousState)`.
	.GetState function -- Returns the current state.
	.GetPreviousState function -- Returns the previous state after the last accepted transition.
	.IsInState function -- Returns whether the machine currently matches the requested state.
	.HasState function -- Returns whether the machine knows about the requested state.
	.GetAllowedTransitions function -- Returns all legal target states from the current state.
	.CanTransition function -- Returns whether a transition is legal from the current state.
	.RegisterOnEnter function -- Registers a runtime enter hook for a known state.
	.RegisterOnExit function -- Registers a runtime exit hook for a known state.
	.RegisterTransitionAction function -- Registers a runtime action for a known transition.
	.RegisterTransitionGuard function -- Registers a runtime guard for a known transition.
	.Transition function -- Attempts a transition and returns a Result.
	.ForceState function -- Bypasses legality checks and forces the new state when it is known.
	.Reset function -- Forces the machine back to the configured initial state.
	.Destroy function -- Releases the StateChanged signal and marks the machine unusable.
]=]
export type TStateMachine<TState> = {
	StateChanged: StateChangedSignal<TState>,
	_state: TState,
	_previousState: TState?,
	_initialState: TState,
	_knownStates: { [any]: boolean },
	_transitions: TTransitionMap<TState>,
	_stateHooks: TStateHookMap<TState>,
	_runtimeOnEnterHooks: { [any]: { TStateHookRegistration<TStateEnterHook<TState>> } },
	_runtimeOnExitHooks: { [any]: { TStateHookRegistration<TStateExitHook<TState>> } },
	_runtimeTransitions: TTransitionRuntimeRegistry<TState>,
	_errorType: string,
	_errorMessage: string,
	_errorDataBuilder: ((fromState: TState, toState: TState) -> TTransitionErrorData)?,
	_isDestroyed: boolean,
	_isTransitioning: boolean,

	GetState: (self: TStateMachine<TState>) -> TState,
	GetPreviousState: (self: TStateMachine<TState>) -> TState?,
	IsInState: (self: TStateMachine<TState>, state: TState) -> boolean,
	HasState: (self: TStateMachine<TState>, state: TState) -> boolean,
	GetAllowedTransitions: (self: TStateMachine<TState>) -> { TState },
	CanTransition: (self: TStateMachine<TState>, newState: TState) -> boolean,
	RegisterOnEnter: (
		self: TStateMachine<TState>,
		state: TState,
		callback: TStateEnterHook<TState>
	) -> RuntimeRegistrationConnection,
	RegisterOnExit: (
		self: TStateMachine<TState>,
		state: TState,
		callback: TStateExitHook<TState>
	) -> RuntimeRegistrationConnection,
	RegisterTransitionAction: (
		self: TStateMachine<TState>,
		fromState: TState,
		toState: TState,
		callback: TTransitionAction<TState>
	) -> RuntimeRegistrationConnection,
	RegisterTransitionGuard: (
		self: TStateMachine<TState>,
		fromState: TState,
		toState: TState,
		callback: TTransitionGuard<TState>
	) -> RuntimeRegistrationConnection,
	Transition: (self: TStateMachine<TState>, newState: TState) -> Result.Result<TState>,
	ForceState: (self: TStateMachine<TState>, newState: TState) -> Result.Result<TState>,
	Reset: (self: TStateMachine<TState>) -> Result.Result<TState>,
	Destroy: (self: TStateMachine<TState>) -> (),
	_BuildTransitionErrorData: (self: TStateMachine<TState>, fromState: TState, toState: TState) -> TTransitionErrorData,
	_BuildDestroyedError: (self: TStateMachine<TState>) -> Result.Err,
	_BuildTransitionInProgressError: (self: TStateMachine<TState>, toState: TState) -> Result.Err,
	_BuildUnknownStateError: (self: TStateMachine<TState>, toState: TState) -> Result.Err,
	_BuildIllegalTransitionError: (self: TStateMachine<TState>, fromState: TState, toState: TState) -> Result.Err,
	_GetTransitionDefinition: (self: TStateMachine<TState>, fromState: TState, toState: TState) -> TTransitionDefinition<TState>?,
	_GetRuntimeTransitionRegistrations: (
		self: TStateMachine<TState>,
		fromState: TState,
		toState: TState
	) -> TTransitionRuntimeRegistrations<TState>,
	_EvaluateGuard: (self: TStateMachine<TState>, definition: TTransitionDefinition<TState>?, fromState: TState, toState: TState) -> Result.Err?,
	_ApplyTransition: (self: TStateMachine<TState>, fromState: TState, toState: TState, definition: TTransitionDefinition<TState>?) -> (),
	_AssertCanRegister: (self: TStateMachine<TState>, state: TState) -> (),
	_AssertCanRegisterTransition: (self: TStateMachine<TState>, fromState: TState, toState: TState) -> (),
}

local RuntimeRegistrationConnection = {}
RuntimeRegistrationConnection.__index = RuntimeRegistrationConnection

function RuntimeRegistrationConnection.new<TCallback>(
	registration: TStateHookRegistration<TCallback>
): RuntimeRegistrationConnection
	local self = setmetatable({}, RuntimeRegistrationConnection)
	self._registration = registration
	return self
end

function RuntimeRegistrationConnection:Disconnect()
	local registration = (self :: any)._registration
	if registration == nil or not registration.Connected then
		return
	end

	registration.Connected = false
end

local function _CreateRuntimeTransitionRegistrations<TState>(): TTransitionRuntimeRegistrations<TState>
	return {
		Guards = {},
		Actions = {},
	}
end

local function _GetActiveCallbacks<TCallback>(
	registrations: { TStateHookRegistration<TCallback> }
): { TCallback }
	local callbacks = {}

	for _, registration in registrations do
		if registration.Connected then
			table.insert(callbacks, registration.Callback)
		end
	end

	return callbacks
end

local function _CollectKnownStates<TState>(
	initialState: TState,
	transitions: TTransitionMap<TState>,
	stateHooks: TStateHookMap<TState>?
): { [any]: boolean }
	local knownStates = {
		[initialState] = true,
	}

	for fromState, targets in transitions do
		assert(type(targets) == "table", INVALID_TRANSITIONS_ERROR_MESSAGE)
		knownStates[fromState] = true

		for toState, entry in targets do
			local entryType = type(entry)
			assert(entryType == "boolean" or entryType == "table", INVALID_TRANSITION_ENTRY_ERROR_MESSAGE)
			if entryType == "boolean" then
				assert(entry == true, INVALID_TRANSITION_ENTRY_ERROR_MESSAGE)
			end

			knownStates[toState] = true
		end
	end

	if stateHooks ~= nil then
		for state in stateHooks do
			knownStates[state] = true
		end
	end

	return knownStates
end

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

	local stateHooks = config.StateHooks or {}
	local knownStates = _CollectKnownStates(config.InitialState, config.Transitions, stateHooks)

	local self = setmetatable({}, StateMachine) :: any
	self._state = config.InitialState
	self._previousState = nil
	self._initialState = config.InitialState
	self._knownStates = knownStates
	self._transitions = config.Transitions
	self._stateHooks = stateHooks
	self._runtimeOnEnterHooks = {}
	self._runtimeOnExitHooks = {}
	self._runtimeTransitions = {}
	self._errorType = config.ErrorType or DEFAULT_ERROR_TYPE
	self._errorMessage = config.ErrorMessage or DEFAULT_ERROR_MESSAGE
	self._errorDataBuilder = config.ErrorDataBuilder
	self._isDestroyed = false
	self._isTransitioning = false
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
	Returns the previous state from the last accepted transition.
	@within StateMachine
	@return any? -- The previous state, if any transition has completed.
]=]
function StateMachine:GetPreviousState<TState>(): TState?
	local machine = self :: TStateMachine<TState>
	return machine._previousState
end

--[=[
	Returns whether the machine currently matches the requested state.
	@within StateMachine
	@param state any -- State to compare.
	@return boolean -- `true` when the machine is already in the requested state.
]=]
function StateMachine:IsInState<TState>(state: TState): boolean
	local machine = self :: TStateMachine<TState>
	return machine._state == state
end

--[=[
	Returns whether the requested state is registered with the machine.
	@within StateMachine
	@param state any -- State to test.
	@return boolean -- `true` when the state exists in the machine graph or hooks.
]=]
function StateMachine:HasState<TState>(state: TState): boolean
	local machine = self :: TStateMachine<TState>
	return machine._knownStates[state] == true
end

--[=[
	Returns the legal target states from the current state.
	@within StateMachine
	@return table -- List of legal target states.
]=]
function StateMachine:GetAllowedTransitions<TState>(): { TState }
	local machine = self :: TStateMachine<TState>
	local legalTargets = machine._transitions[machine._state]
	local allowedTransitions = {}

	if legalTargets == nil then
		return allowedTransitions
	end

	for state in legalTargets do
		table.insert(allowedTransitions, state)
	end

	return allowedTransitions
end

--[=[
	Returns whether the requested state is legal from the current state.
	@within StateMachine
	@param newState any -- Target state to evaluate.
	@return boolean -- `true` when the transition is legal.
]=]
function StateMachine:CanTransition<TState>(newState: TState): boolean
	local machine = self :: TStateMachine<TState>

	if machine._isDestroyed or machine._isTransitioning then
		return false
	end

	local fromState = machine._state
	local definition = machine:_GetTransitionDefinition(fromState, newState)
	if definition == nil then
		return false
	end

	return machine:_EvaluateGuard(definition, fromState, newState) == nil
end

--[=[
	Registers a runtime enter hook for a known state.
	@within StateMachine
	@param state any -- Known target state.
	@param callback function -- Hook called after config enter hooks.
	@return RuntimeRegistrationConnection -- Connection used to unregister the hook.
]=]
function StateMachine:RegisterOnEnter<TState>(
	state: TState,
	callback: TStateEnterHook<TState>
): RuntimeRegistrationConnection
	local machine = self :: TStateMachine<TState>
	machine:_AssertCanRegister(state)

	local registrations = machine._runtimeOnEnterHooks[state]
	if registrations == nil then
		registrations = {}
		machine._runtimeOnEnterHooks[state] = registrations
	end

	local registration = {
		Connected = true,
		Callback = callback,
	}
	table.insert(registrations, registration)

	return RuntimeRegistrationConnection.new(registration)
end

--[=[
	Registers a runtime exit hook for a known state.
	@within StateMachine
	@param state any -- Known source state.
	@param callback function -- Hook called after config exit hooks.
	@return RuntimeRegistrationConnection -- Connection used to unregister the hook.
]=]
function StateMachine:RegisterOnExit<TState>(
	state: TState,
	callback: TStateExitHook<TState>
): RuntimeRegistrationConnection
	local machine = self :: TStateMachine<TState>
	machine:_AssertCanRegister(state)

	local registrations = machine._runtimeOnExitHooks[state]
	if registrations == nil then
		registrations = {}
		machine._runtimeOnExitHooks[state] = registrations
	end

	local registration = {
		Connected = true,
		Callback = callback,
	}
	table.insert(registrations, registration)

	return RuntimeRegistrationConnection.new(registration)
end

--[=[
	Registers a runtime action for a known transition.
	@within StateMachine
	@param fromState any -- Known source state.
	@param toState any -- Known target state.
	@param callback function -- Action called after config transition actions.
	@return RuntimeRegistrationConnection -- Connection used to unregister the action.
]=]
function StateMachine:RegisterTransitionAction<TState>(
	fromState: TState,
	toState: TState,
	callback: TTransitionAction<TState>
): RuntimeRegistrationConnection
	local machine = self :: TStateMachine<TState>
	machine:_AssertCanRegisterTransition(fromState, toState)

	local registrations = machine:_GetRuntimeTransitionRegistrations(fromState, toState)
	local registration = {
		Connected = true,
		Callback = callback,
	}
	table.insert(registrations.Actions, registration)

	return RuntimeRegistrationConnection.new(registration)
end

--[=[
	Registers a runtime guard for a known transition.
	@within StateMachine
	@param fromState any -- Known source state.
	@param toState any -- Known target state.
	@param callback function -- Guard called after the config transition guard.
	@return RuntimeRegistrationConnection -- Connection used to unregister the guard.
]=]
function StateMachine:RegisterTransitionGuard<TState>(
	fromState: TState,
	toState: TState,
	callback: TTransitionGuard<TState>
): RuntimeRegistrationConnection
	local machine = self :: TStateMachine<TState>
	machine:_AssertCanRegisterTransition(fromState, toState)

	local registrations = machine:_GetRuntimeTransitionRegistrations(fromState, toState)
	local registration = {
		Connected = true,
		Callback = callback,
	}
	table.insert(registrations.Guards, registration)

	return RuntimeRegistrationConnection.new(registration)
end

--[=[
	Attempts to move the machine into a new state.
	@within StateMachine
	@param newState any -- Target state to enter.
	@return Result.Result -- `Ok(newState)` when accepted, or `Err` when rejected.
]=]
function StateMachine:Transition<TState>(newState: TState): Result.Result<TState>
	local machine = self :: TStateMachine<TState>

	if machine._isDestroyed then
		return machine:_BuildDestroyedError()
	end

	if machine._isTransitioning then
		return machine:_BuildTransitionInProgressError(newState)
	end

	local previousState = machine._state
	local definition = machine:_GetTransitionDefinition(previousState, newState)
	if definition == nil then
		return machine:_BuildIllegalTransitionError(previousState, newState)
	end

	local guardError = machine:_EvaluateGuard(definition, previousState, newState)
	if guardError ~= nil then
		return guardError
	end

	machine:_ApplyTransition(previousState, newState, definition)
	return Result.Ok(newState)
end

--[=[
	Forces the machine into a known state without legality checks.
	@within StateMachine
	@param newState any -- Target state to enter.
	@return Result.Result -- `Ok(newState)` when accepted, or `Err` when rejected.
]=]
function StateMachine:ForceState<TState>(newState: TState): Result.Result<TState>
	local machine = self :: TStateMachine<TState>

	if machine._isDestroyed then
		return machine:_BuildDestroyedError()
	end

	if machine._isTransitioning then
		return machine:_BuildTransitionInProgressError(newState)
	end

	if not machine:HasState(newState) then
		return machine:_BuildUnknownStateError(newState)
	end

	local previousState = machine._state
	machine:_ApplyTransition(previousState, newState, nil)
	return Result.Ok(newState)
end

--[=[
	Forces the machine back to its configured initial state.
	@within StateMachine
	@return Result.Result -- `Ok(initialState)` when accepted, or `Err` when rejected.
]=]
function StateMachine:Reset<TState>(): Result.Result<TState>
	local machine = self :: TStateMachine<TState>
	return machine:ForceState(machine._initialState)
end

--[=[
	Releases the state-change signal and marks the machine unusable.
	@within StateMachine
]=]
function StateMachine:Destroy<TState>()
	local machine = self :: TStateMachine<TState>
	if machine._isDestroyed then
		return
	end

	machine._isDestroyed = true
	machine._runtimeOnEnterHooks = {}
	machine._runtimeOnExitHooks = {}
	machine._runtimeTransitions = {}
	machine.StateChanged:DisconnectAll()
end

function StateMachine:_BuildTransitionErrorData<TState>(fromState: TState, toState: TState): TTransitionErrorData
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

function StateMachine:_BuildDestroyedError<TState>(): Result.Err
	local machine = self :: TStateMachine<TState>
	return Result.Err(DESTROYED_ERROR_TYPE, DESTROYED_ERROR_MESSAGE, {
		State = machine._state,
	})
end

function StateMachine:_BuildTransitionInProgressError<TState>(toState: TState): Result.Err
	local machine = self :: TStateMachine<TState>
	return Result.Err(TRANSITION_IN_PROGRESS_ERROR_TYPE, TRANSITION_IN_PROGRESS_ERROR_MESSAGE, {
		From = machine._state,
		To = toState,
	})
end

function StateMachine:_BuildUnknownStateError<TState>(toState: TState): Result.Err
	local machine = self :: TStateMachine<TState>
	return Result.Err(UNKNOWN_STATE_ERROR_TYPE, UNKNOWN_STATE_ERROR_MESSAGE, {
		From = machine._state,
		To = toState,
	})
end

function StateMachine:_BuildIllegalTransitionError<TState>(fromState: TState, toState: TState): Result.Err
	local machine = self :: TStateMachine<TState>
	return Result.Err(machine._errorType, machine._errorMessage, machine:_BuildTransitionErrorData(fromState, toState))
end

function StateMachine:_GetTransitionDefinition<TState>(
	fromState: TState,
	toState: TState
): TTransitionDefinition<TState>?
	local machine = self :: TStateMachine<TState>
	local legalTargets = machine._transitions[fromState]
	if legalTargets == nil then
		return nil
	end

	local transitionEntry = legalTargets[toState]
	if transitionEntry == nil then
		return nil
	end

	if transitionEntry == true then
		return {}
	end

	return transitionEntry :: TTransitionDefinition<TState>
end

function StateMachine:_GetRuntimeTransitionRegistrations<TState>(
	fromState: TState,
	toState: TState
): TTransitionRuntimeRegistrations<TState>
	local machine = self :: TStateMachine<TState>
	local fromRegistrations = machine._runtimeTransitions[fromState]
	if fromRegistrations == nil then
		fromRegistrations = {}
		machine._runtimeTransitions[fromState] = fromRegistrations
	end

	local transitionRegistrations = fromRegistrations[toState]
	if transitionRegistrations == nil then
		transitionRegistrations = _CreateRuntimeTransitionRegistrations()
		fromRegistrations[toState] = transitionRegistrations
	end

	return transitionRegistrations
end

function StateMachine:_EvaluateGuard<TState>(
	definition: TTransitionDefinition<TState>?,
	fromState: TState,
	toState: TState
): Result.Err?
	local machine = self :: TStateMachine<TState>

	if definition ~= nil and definition.Guard ~= nil then
		local guardError = definition.Guard(fromState, toState)
		if guardError ~= nil then
			return guardError
		end
	end

	local transitionRegistrations = machine._runtimeTransitions[fromState]
	if transitionRegistrations == nil then
		return nil
	end

	local runtimeRegistrations = transitionRegistrations[toState]
	if runtimeRegistrations == nil then
		return nil
	end

	for _, guard in _GetActiveCallbacks(runtimeRegistrations.Guards) do
		local guardError = guard(fromState, toState)
		if guardError ~= nil then
			return guardError
		end
	end

	return nil
end

function StateMachine:_ApplyTransition<TState>(
	fromState: TState,
	toState: TState,
	definition: TTransitionDefinition<TState>?
)
	local machine = self :: TStateMachine<TState>
	local fromHooks = machine._stateHooks[fromState]
	local toHooks = machine._stateHooks[toState]
	local action = if definition ~= nil then definition.Action else nil
	local runtimeExitHooks = _GetActiveCallbacks(machine._runtimeOnExitHooks[fromState] or {})
	local runtimeEnterHooks = _GetActiveCallbacks(machine._runtimeOnEnterHooks[toState] or {})
	local transitionRegistrations = machine._runtimeTransitions[fromState]
	local runtimeActions = if transitionRegistrations ~= nil and transitionRegistrations[toState] ~= nil
		then _GetActiveCallbacks(transitionRegistrations[toState].Actions)
		else {}

	machine._isTransitioning = true

	local ok, thrownError = xpcall(function()
		if fromHooks ~= nil and fromHooks.OnExit ~= nil then
			fromHooks.OnExit(fromState, toState)
		end
		for _, exitHook in runtimeExitHooks do
			exitHook(fromState, toState)
		end

		machine._previousState = fromState
		machine._state = toState

		if action ~= nil then
			action(fromState, toState)
		end
		for _, runtimeAction in runtimeActions do
			runtimeAction(fromState, toState)
		end

		if toHooks ~= nil and toHooks.OnEnter ~= nil then
			toHooks.OnEnter(toState, fromState)
		end
		for _, enterHook in runtimeEnterHooks do
			enterHook(toState, fromState)
		end

		machine.StateChanged:Fire(toState, fromState)
	end, debug.traceback)

	machine._isTransitioning = false

	if not ok then
		error(thrownError, 0)
	end
end

function StateMachine:_AssertCanRegister<TState>(state: TState)
	local machine = self :: TStateMachine<TState>
	assert(not machine._isDestroyed, DESTROYED_ERROR_MESSAGE)
	assert(machine:HasState(state), UNKNOWN_STATE_ERROR_MESSAGE)
end

function StateMachine:_AssertCanRegisterTransition<TState>(fromState: TState, toState: TState)
	local machine = self :: TStateMachine<TState>
	machine:_AssertCanRegister(fromState)
	machine:_AssertCanRegister(toState)
	assert(machine:_GetTransitionDefinition(fromState, toState) ~= nil, DEFAULT_ERROR_MESSAGE)
end

return table.freeze(StateMachine)
