--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local Enums = require(script.Parent.Enums)
local Policies = require(script.Parent.Policies)
local Signals = require(script.Parent.Signals)
local Types = require(script.Parent.Types)

type TProximityEligibilityContext = Types.TProximityEligibilityContext
type TProximityHandle = Types.TProximityHandle
type TProximityHandleState = Types.TProximityHandleState
type TProximityTarget = Types.TProximityTarget
type TRegistrationMode = Types.TRegistrationMode
type TResolvedProximityOptions = Types.TResolvedProximityOptions

local OWNED_PROMPT_KEY = "OwnedPrompt"
local STATE_MACHINE_KEY = "StateMachine"
local SHOWN_SIGNAL_KEY = "ShownSignal"
local HIDDEN_SIGNAL_KEY = "HiddenSignal"
local TRIGGERED_SIGNAL_KEY = "TriggeredSignal"
local HOLD_STARTED_SIGNAL_KEY = "HoldStartedSignal"
local HOLD_ENDED_SIGNAL_KEY = "HoldEndedSignal"
local DESTROYED_SIGNAL_KEY = "DestroyedSignal"
local TRIGGERED_CONNECTION_KEY = "TriggeredConnection"
local HOLD_STARTED_CONNECTION_KEY = "HoldStartedConnection"
local HOLD_ENDED_CONNECTION_KEY = "HoldEndedConnection"

local TRANSITIONS: { [TProximityHandleState]: { [TProximityHandleState]: boolean } } = {
	[Enums.HandleState.Registered] = {
		[Enums.HandleState.Shown] = true,
		[Enums.HandleState.Hidden] = true,
		[Enums.HandleState.Disabled] = true,
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Shown] = {
		[Enums.HandleState.Hidden] = true,
		[Enums.HandleState.Disabled] = true,
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Hidden] = {
		[Enums.HandleState.Shown] = true,
		[Enums.HandleState.Disabled] = true,
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Disabled] = {
		[Enums.HandleState.Shown] = true,
		[Enums.HandleState.Hidden] = true,
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Destroyed] = {},
}

local Handle = {}
Handle.__index = Handle

function Handle.new(
	manager: any,
	key: string,
	target: TProximityTarget,
	prompt: ProximityPrompt,
	ownsPrompt: boolean,
	options: TResolvedProximityOptions,
	mode: TRegistrationMode,
	stash: any
): TProximityHandle
	local self = setmetatable({}, Handle) :: any
	self._manager = manager
	self._key = key
	self._target = target
	self._prompt = prompt
	self._ownsPrompt = ownsPrompt
	self._options = options
	self._mode = mode
	self._stash = stash
	self._isDestroyed = false
	self._enabled = options.Enabled
	self._stateMachine = StateMachine.new({
		InitialState = Enums.HandleState.Registered,
		Transitions = TRANSITIONS,
		ErrorType = Enums.ErrorKey.IllegalProximityHandleTransition.Name,
		ErrorMessage = Enums.ErrorMessage[Enums.ErrorKey.IllegalProximityHandleTransition],
		ErrorDataBuilder = function(fromState: TProximityHandleState, toState: TProximityHandleState)
			return {
				From = fromState.Name,
				To = toState.Name,
			}
		end,
	})
	self.StateChanged = self._stateMachine.StateChanged
	self.Shown = Signals.Create(stash, SHOWN_SIGNAL_KEY)
	self.Hidden = Signals.Create(stash, HIDDEN_SIGNAL_KEY)
	self.Triggered = Signals.Create(stash, TRIGGERED_SIGNAL_KEY)
	self.HoldStarted = Signals.Create(stash, HOLD_STARTED_SIGNAL_KEY)
	self.HoldEnded = Signals.Create(stash, HOLD_ENDED_SIGNAL_KEY)
	self.Destroyed = Signals.Create(stash, DESTROYED_SIGNAL_KEY)

	self._stash:Add(self._stateMachine, {
		CleanupMethod = "Destroy",
		Key = STATE_MACHINE_KEY,
		Label = STATE_MACHINE_KEY,
	})

	if ownsPrompt then
		self._stash:AddInstance(prompt, {
			Key = OWNED_PROMPT_KEY,
			Label = OWNED_PROMPT_KEY,
		})
	end

	self:_ConnectPromptEvents()
	self:Refresh()

	return self
end

function Handle:GetPrompt(): ProximityPrompt
	return self._prompt
end

function Handle:GetKey(): string
	return self._key
end

function Handle:GetActionKind(): any
	return self._options.ActionKind
end

function Handle:GetTarget(): TProximityTarget
	return self._target
end

function Handle:GetState(): TProximityHandleState
	return self._stateMachine:GetState()
end

function Handle:GetMetadata(): { [string]: any }?
	return self._options.Metadata
end

function Handle:IsVisible(): boolean
	return self._stateMachine:GetState() == Enums.HandleState.Shown
end

function Handle:SetEnabled(enabled: boolean)
	Policies.CheckHandleAlive(self)
	assert(type(enabled) == "boolean", Enums.ErrorMessage[Enums.ErrorKey.InvalidEnabled])

	self._enabled = enabled
	self:Refresh()
end

function Handle:Refresh()
	Policies.CheckHandleAlive(self)

	-- Resolve the desired visibility state from the static options and runtime gate.
	local nextState = self:_ResolveState()
	local currentState = self._stateMachine:GetState()
	if currentState == nextState then
		self._prompt.Enabled = nextState == Enums.HandleState.Shown
		return
	end

	-- Apply the state transition before firing the outward-facing signals.
	Policies.CheckHandleTransition(self, nextState)
	self._stateMachine:Transition(nextState)
	self._prompt.Enabled = nextState == Enums.HandleState.Shown
	self:_EmitVisibilitySignals(currentState, nextState)
end

function Handle:Destroy()
	if self._isDestroyed then
		return
	end

	-- Move to the terminal state before the stash tears down owned resources.
	local currentState = self._stateMachine:GetState()
	if currentState ~= Enums.HandleState.Destroyed then
		Policies.CheckHandleTransition(self, Enums.HandleState.Destroyed)
		self._stateMachine:Transition(Enums.HandleState.Destroyed)
	end

	self._manager:_ForgetHandle(self._key, self)
	self._isDestroyed = true

	if currentState == Enums.HandleState.Shown then
		self.Hidden:Fire(self._prompt, self)
		self:_InvokeCallback(self._options.OnHidden, nil)
	end

	self.Destroyed:Fire(self)
	self._stash:Destroy()
end

function Handle:_ConnectPromptEvents()
	self._stash:AddConnection(self._prompt.Triggered:Connect(function(player: Player?)
		self:_HandleTriggered(player)
	end), {
		Key = TRIGGERED_CONNECTION_KEY,
		Label = TRIGGERED_CONNECTION_KEY,
	})

	self._stash:AddConnection(self._prompt.PromptButtonHoldBegan:Connect(function(player: Player?)
		self:_HandleHoldStarted(player)
	end), {
		Key = HOLD_STARTED_CONNECTION_KEY,
		Label = HOLD_STARTED_CONNECTION_KEY,
	})

	self._stash:AddConnection(self._prompt.PromptButtonHoldEnded:Connect(function(player: Player?)
		self:_HandleHoldEnded(player)
	end), {
		Key = HOLD_ENDED_CONNECTION_KEY,
		Label = HOLD_ENDED_CONNECTION_KEY,
	})
end

function Handle:_BuildEligibilityContext(): TProximityEligibilityContext
	return {
		Manager = self._manager,
		Handle = self,
		Key = self._key,
		ActionKind = self._options.ActionKind,
		Target = self._target,
		Prompt = self._prompt,
		State = self._stateMachine:GetState(),
		Enabled = self._enabled,
		OwnsPrompt = self._ownsPrompt,
		Mode = self._mode,
	}
end

function Handle:_ResolveState(): TProximityHandleState
	if not self._enabled then
		return Enums.HandleState.Disabled
	end

	local canShow = self._options.CanShow
	if canShow ~= nil and not canShow(self:_BuildEligibilityContext()) then
		return Enums.HandleState.Hidden
	end

	return Enums.HandleState.Shown
end

function Handle:_EmitVisibilitySignals(previousState: TProximityHandleState, nextState: TProximityHandleState)
	if nextState == Enums.HandleState.Shown then
		self.Shown:Fire(self._prompt, self)
		self:_InvokeCallback(self._options.OnShown, nil)
	end

	if previousState == Enums.HandleState.Shown and nextState ~= Enums.HandleState.Shown then
		self.Hidden:Fire(self._prompt, self)
		self:_InvokeCallback(self._options.OnHidden, nil)
	end
end

function Handle:_CanTrigger(player: Player?): boolean
	if self._stateMachine:GetState() ~= Enums.HandleState.Shown then
		return false
	end

	local canTrigger = self._options.CanTrigger
	if canTrigger == nil then
		return true
	end

	return canTrigger(self:_BuildEligibilityContext(), player)
end

function Handle:_HandleTriggered(player: Player?)
	if not self:_CanTrigger(player) then
		return
	end

	self.Triggered:Fire(player, self._prompt, self)
	self:_InvokeCallback(self._options.OnTriggered, player)
end

function Handle:_HandleHoldStarted(player: Player?)
	if not self:_CanTrigger(player) then
		return
	end

	self.HoldStarted:Fire(player, self._prompt, self)
	self:_InvokeCallback(self._options.OnHoldStarted, player)
end

function Handle:_HandleHoldEnded(player: Player?)
	if not self:_CanTrigger(player) then
		return
	end

	self.HoldEnded:Fire(player, self._prompt, self)
	self:_InvokeCallback(self._options.OnHoldEnded, player)
end

function Handle:_InvokeCallback(callback: ((Player?, ProximityPrompt, TProximityHandle) -> ())?, player: Player?)
	if callback == nil then
		return
	end

	callback(player, self._prompt, self)
end

return table.freeze(Handle)
