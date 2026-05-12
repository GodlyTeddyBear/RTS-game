--!strict

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Result = require(ReplicatedStorage.Utilities.Result)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local Config = require(script.Config)
local Constants = require(script.Constants)
local Snapshot = require(script.Snapshot)
local Types = require(script.Types)
local useMenu = require(script.useMenu)
local useMenuActions = require(script.useMenuActions)

-- Constants
local ACTION_OPEN = Constants.Action.Open
local ACTION_CLOSE = Constants.Action.Close
local ACTION_GO_TO = Constants.Action.GoTo
local ACTION_BACK = Constants.Action.Back
local ACTION_RESET = Constants.Action.Reset
local ACTION_SET_CONTEXT = Constants.Action.SetContext
local ACTION_CLEAR_CONTEXT = Constants.Action.ClearContext

local CLOSED_STATE = Constants.State.Closed

local ERROR_MENU_ALREADY_OPEN = Constants.Error.MenuAlreadyOpen
local ERROR_MENU_ALREADY_CLOSED = Constants.Error.MenuAlreadyClosed
local ERROR_MENU_INVALID_TARGET = Constants.Error.MenuInvalidTarget
local ERROR_MENU_UNKNOWN_STATE = Constants.Error.MenuUnknownState
local ERROR_MENU_BACK_UNAVAILABLE = Constants.Error.MenuBackUnavailable
local ERROR_MENU_DESTROYED = Constants.Error.MenuDestroyed

-- Types
export type TMenuStateMeta = Types.TMenuStateMeta
export type TMenuStateNode = Types.TMenuStateNode
export type TMenuConfig = Types.TMenuConfig
export type TMenuSnapshot = Types.TMenuSnapshot
export type TMenuTransitionAction = Types.TMenuTransitionAction
export type TMenuTransitionInfo = Types.TMenuTransitionInfo

type TChangedSignal = Types.TChangedSignal
type TInternalMenuState = Types.TInternalMenuState
type TNormalizedMenuConfig = Types.TNormalizedMenuConfig

export type TMenuController = {
	Changed: TChangedSignal,
	StateChanged: any,
	_config: TNormalizedMenuConfig,
	_machine: StateMachine.TStateMachine<TInternalMenuState>,
	_snapshot: TMenuSnapshot,
	_isDestroyed: boolean,

	Open: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	Close: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	GoTo: (self: TMenuController, stateId: string, payload: { [string]: any }?) -> Result.Result<TMenuSnapshot>,
	Back: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	Reset: (self: TMenuController) -> Result.Result<TMenuSnapshot>,
	SetContext: (self: TMenuController, patch: { [string]: any }) -> Result.Result<TMenuSnapshot>,
	ClearContext: (self: TMenuController, ...string) -> Result.Result<TMenuSnapshot>,
	GetSnapshot: (self: TMenuController) -> TMenuSnapshot,
	CanGoTo: (self: TMenuController, stateId: string) -> boolean,
	CanGoBack: (self: TMenuController) -> boolean,
	Destroy: (self: TMenuController) -> (),
}

-- Module
local MenuController = {}
MenuController.__index = MenuController

-- Constructor
function MenuController.new(config: TMenuConfig): TMenuController
	local normalizedConfig = Config.NormalizeConfig(config)

	local self = setmetatable({}, MenuController) :: any
	self._config = normalizedConfig
	self._machine = StateMachine.new({
		InitialState = CLOSED_STATE,
		Transitions = normalizedConfig.Transitions,
		ErrorType = ERROR_MENU_INVALID_TARGET,
		ErrorMessage = "State transition is not allowed",
		ErrorDataBuilder = function(fromState: TInternalMenuState, toState: TInternalMenuState)
			return {
				MenuId = normalizedConfig.Id,
				From = fromState,
				To = toState,
			}
		end,
	})
	self._snapshot = Snapshot.CreateSnapshotFromMachineState(self._machine:GetState(), {}, {}, normalizedConfig)
	self._isDestroyed = false
	self.Changed = GoodSignal.new()
	self.StateChanged = self._machine.StateChanged

	return self
end

-- Public methods
function MenuController:Open(): Result.Result<TMenuSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_OPEN)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	if self:_IsOpen() then
		return self:_BuildStateError(ERROR_MENU_ALREADY_OPEN, "Menu is already open", ACTION_OPEN, nil)
	end

	return self:_TransitionMachine(ACTION_OPEN, self._config.InitialState, self._snapshot.History, self._snapshot.Context, nil, nil)
end

function MenuController:Close(): Result.Result<TMenuSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_CLOSE)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	if not self:_IsOpen() then
		return self:_BuildStateError(ERROR_MENU_ALREADY_CLOSED, "Menu is already closed", ACTION_CLOSE, nil)
	end

	return self:_TransitionMachine(ACTION_CLOSE, CLOSED_STATE, {}, {}, nil, nil)
end

function MenuController:GoTo(stateId: string, payload: { [string]: any }?): Result.Result<TMenuSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_GO_TO)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	local openStateResult = self:_GuardOpenState(ACTION_GO_TO)
	if openStateResult ~= nil then
		return openStateResult
	end

	local contextPatchResult = Snapshot.ValidateContextPatch(payload)
	if contextPatchResult ~= nil then
		return contextPatchResult
	end

	if self._config.States[stateId] == nil then
		return self:_BuildStateError(ERROR_MENU_UNKNOWN_STATE, "Target state is not registered", ACTION_GO_TO, {
			ToState = stateId,
		})
	end

	local previousState = self._snapshot.CurrentState :: string
	local nextHistory = Snapshot.CloneHistoryWithPush(self._snapshot.History, previousState)
	local nextContext = Snapshot.MergeContext(self._snapshot.Context, payload)

	return self:_TransitionMachine(
		ACTION_GO_TO,
		stateId,
		nextHistory,
		nextContext,
		if payload then table.freeze(table.clone(payload)) else nil,
		nil
	)
end

function MenuController:Back(): Result.Result<TMenuSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_BACK)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	local openStateResult = self:_GuardOpenState(ACTION_BACK)
	if openStateResult ~= nil then
		return openStateResult
	end

	if not self:CanGoBack() then
		return self:_BuildStateError(ERROR_MENU_BACK_UNAVAILABLE, "Menu history is empty", ACTION_BACK, nil)
	end

	local nextHistory, targetState = Snapshot.CloneHistoryWithPop(self._snapshot.History)
	return self:_TransitionMachine(ACTION_BACK, targetState, nextHistory, self._snapshot.Context, nil, nil)
end

function MenuController:Reset(): Result.Result<TMenuSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_RESET)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	return self:_TransitionMachine(ACTION_RESET, CLOSED_STATE, {}, {}, nil, nil)
end

function MenuController:SetContext(patch: { [string]: any }): Result.Result<TMenuSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_SET_CONTEXT)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	local openStateResult = self:_GuardOpenState(ACTION_SET_CONTEXT)
	if openStateResult ~= nil then
		return openStateResult
	end

	local contextPatchResult = Snapshot.ValidateContextPatch(patch)
	if contextPatchResult ~= nil then
		return contextPatchResult
	end

	local nextContext = Snapshot.MergeContext(self._snapshot.Context, patch)
	local nextSnapshot = Snapshot.CreateSnapshotFromMachineState(
		self._machine:GetState(),
		self._snapshot.History,
		nextContext,
		self._config
	)

	return self:_Commit(nextSnapshot, {
		Action = ACTION_SET_CONTEXT,
		FromState = self._snapshot.CurrentState,
		ToState = self._snapshot.CurrentState,
		ContextPatch = table.freeze(table.clone(patch)),
	})
end

function MenuController:ClearContext(...: string): Result.Result<TMenuSnapshot>
	local destroyedResult = self:_GuardDestroyed(ACTION_CLEAR_CONTEXT)
	if destroyedResult ~= nil then
		return destroyedResult
	end

	local openStateResult = self:_GuardOpenState(ACTION_CLEAR_CONTEXT)
	if openStateResult ~= nil then
		return openStateResult
	end

	local keys = { ... }
	local keyValidationResult = Snapshot.ValidateClearContextKeys(keys)
	if keyValidationResult ~= nil then
		return keyValidationResult
	end

	local nextContext = Snapshot.CloneContextWithoutKeys(self._snapshot.Context, keys)
	local nextSnapshot = Snapshot.CreateSnapshotFromMachineState(
		self._machine:GetState(),
		self._snapshot.History,
		nextContext,
		self._config
	)

	return self:_Commit(nextSnapshot, {
		Action = ACTION_CLEAR_CONTEXT,
		FromState = self._snapshot.CurrentState,
		ToState = self._snapshot.CurrentState,
		ContextPatch = Snapshot.BuildClearContextPatch(keys),
	})
end

function MenuController:GetSnapshot(): TMenuSnapshot
	return self._snapshot
end

function MenuController:CanGoTo(stateId: string): boolean
	if self._isDestroyed or not self:_IsOpen() then
		return false
	end

	return self._machine:CanTransition(stateId)
end

function MenuController:CanGoBack(): boolean
	if self._isDestroyed or not self:_IsOpen() then
		return false
	end

	return #self._snapshot.History > 0
end

function MenuController:Destroy(): ()
	if self._isDestroyed then
		return
	end

	self._isDestroyed = true
	self._machine:Destroy()
	self.Changed:DisconnectAll()
end

-- Private helpers
function MenuController:_TransitionMachine(
	actionName: TMenuTransitionAction,
	targetState: TInternalMenuState,
	nextHistory: { string },
	nextContext: { [string]: any },
	payload: { [string]: any }?,
	contextPatch: { [string]: any }?
): Result.Result<TMenuSnapshot>
	local fromState = self._snapshot.CurrentState
	local transitionResult = self._machine:Transition(targetState)
	if not transitionResult.success then
		return self:_MapTransitionError(actionName, targetState, transitionResult)
	end

	local nextSnapshot = Snapshot.CreateSnapshotFromMachineState(targetState, nextHistory, nextContext, self._config)
	return self:_Commit(nextSnapshot, {
		Action = actionName,
		FromState = fromState,
		ToState = nextSnapshot.CurrentState,
		Payload = payload,
		ContextPatch = contextPatch,
	})
end

function MenuController:_Commit(
	nextSnapshot: TMenuSnapshot,
	transitionInfo: TMenuTransitionInfo
): Result.Result<TMenuSnapshot>
	local previousSnapshot = self._snapshot
	self._snapshot = nextSnapshot
	self.Changed:Fire(nextSnapshot, previousSnapshot, table.freeze(transitionInfo))
	return Result.Ok(nextSnapshot)
end

function MenuController:_GuardDestroyed(actionName: TMenuTransitionAction): Result.Err?
	if not self._isDestroyed then
		return nil
	end

	return self:_BuildStateError(ERROR_MENU_DESTROYED, "Menu controller has been destroyed", actionName, nil)
end

function MenuController:_GuardOpenState(actionName: TMenuTransitionAction): Result.Err?
	if self:_IsOpen() then
		return nil
	end

	return self:_BuildStateError(ERROR_MENU_ALREADY_CLOSED, "Menu is closed", actionName, nil)
end

function MenuController:_BuildStateError(
	errorType: string,
	message: string,
	actionName: TMenuTransitionAction,
	data: { [string]: any }?
): Result.Err
	local currentState = self._snapshot.CurrentState
	local errorData = if data then table.clone(data) else {}
	errorData.MenuId = self._config.Id
	errorData.Action = actionName
	errorData.IsOpen = self._snapshot.IsOpen
	errorData.CurrentState = currentState
	return Result.Err(errorType, message, errorData)
end

function MenuController:_MapTransitionError(
	actionName: TMenuTransitionAction,
	targetState: TInternalMenuState,
	transitionError: Result.Err
): Result.Err
	local currentState = self._snapshot.CurrentState
	local errorData = if transitionError.data then table.clone(transitionError.data) else {}
	errorData.MenuId = self._config.Id
	errorData.Action = actionName
	errorData.IsOpen = self._snapshot.IsOpen
	errorData.CurrentState = currentState
	errorData.ToState = if targetState == CLOSED_STATE then nil else targetState

	if currentState ~= nil then
		errorData.AllowedTargets = Config.CollectAllowedTargets(self._config.Transitions[currentState])
	end

	return Result.Err(ERROR_MENU_INVALID_TARGET, "Target state is not allowed from the current state", errorData)
end

function MenuController:_IsOpen(): boolean
	return self._machine:GetState() ~= CLOSED_STATE
end

return table.freeze({
	new = MenuController.new,
	useMenu = useMenu,
	useMenuActions = useMenuActions,
})
