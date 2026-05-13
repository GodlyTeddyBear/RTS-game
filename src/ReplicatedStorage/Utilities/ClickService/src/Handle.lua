--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Option = require(ReplicatedStorage.Utilities.Option)
local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local Enums = require(script.Parent.Enums)
local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type TClickHandle = Types.TClickHandle
type TClickHandleState = Types.TClickHandleState
type TClickTarget = Types.TClickTarget
type TDetectorBinding = Types.TDetectorBinding
type TResolvedClickOptions = Types.TResolvedClickOptions

local OWNED_DETECTOR_KEY = "OwnedDetector"
local CLICK_CONNECTION_KEY = "ClickConnection"
local CLICK_SIGNAL_KEY = "ClickedSignal"
local STATE_MACHINE_KEY = "StateMachine"

local TRANSITIONS: { [TClickHandleState]: { [TClickHandleState]: boolean } } = {
	[Enums.HandleState.Active] = {
		[Enums.HandleState.Detached] = true,
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Detached] = {
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Destroyed] = {},
}

local Handle = {}
Handle.__index = Handle

function Handle.new(
	manager: any,
	target: TClickTarget,
	resolvedPart: BasePart,
	detectorBinding: TDetectorBinding,
	options: TResolvedClickOptions
): TClickHandle
	local self = setmetatable({}, Handle) :: any
	self._manager = manager
	self._target = target
	self._resolvedPart = resolvedPart
	self._detector = detectorBinding.Detector
	self._options = options
	self._stash = StashPlus.new()
	self._isDestroyed = false
	self.Clicked = GoodSignal.new()
	self._stateMachine = StateMachine.new({
		InitialState = Enums.HandleState.Active,
		Transitions = TRANSITIONS,
		ErrorType = Enums.ErrorKey.IllegalClickHandleTransition.Name,
		ErrorMessage = Enums.ErrorMessage[Enums.ErrorKey.IllegalClickHandleTransition],
		ErrorDataBuilder = function(fromState: TClickHandleState, toState: TClickHandleState)
			return {
				From = fromState.Name,
				To = toState.Name,
			}
		end,
	})
	self.StateChanged = self._stateMachine.StateChanged

	self._stash:Add(self.Clicked, {
		CleanupMethod = "DisconnectAll",
		Key = CLICK_SIGNAL_KEY,
		Label = CLICK_SIGNAL_KEY,
	})
	self._stash:Add(self._stateMachine, {
		CleanupMethod = "Destroy",
		Key = STATE_MACHINE_KEY,
		Label = STATE_MACHINE_KEY,
	})

	if detectorBinding.Created then
		self._stash:AddInstance(detectorBinding.Detector, {
			Key = OWNED_DETECTOR_KEY,
			Label = OWNED_DETECTOR_KEY,
		})
	end

	self._stash:AddConnection(detectorBinding.Detector.MouseClick:Connect(function(player: Player)
		if self._stateMachine:GetState() ~= Enums.HandleState.Active then
			return
		end

		self.Clicked:Fire(player, self._resolvedPart, self)
		self._manager:_HandleClicked(player, self._resolvedPart, self)
	end), {
		Key = CLICK_CONNECTION_KEY,
		Label = CLICK_CONNECTION_KEY,
	})

	return self
end

function Handle:GetTarget(): TClickTarget
	return self._target
end

function Handle:GetResolvedPart(): BasePart
	return self._resolvedPart
end

function Handle:GetDetector(): any
	return Option.Wrap(if self._detector ~= nil and self._detector.Parent ~= nil then self._detector else nil)
end

function Handle:GetState(): TClickHandleState
	return self._stateMachine:GetState()
end

function Handle:IsAttached(): boolean
	return self._stateMachine:GetState() == Enums.HandleState.Active
end

function Handle:Detach(): boolean
	local aliveResult = Policies.CheckHandleAlive(self)
	if not aliveResult.success then
		return false
	end

	if self._stateMachine:GetState() ~= Enums.HandleState.Active then
		return false
	end

	local transitionResult = Policies.CheckHandleTransition(self, Enums.HandleState.Detached)
	if not transitionResult.success then
		return false
	end

	self._stateMachine:Transition(Enums.HandleState.Detached)
	self._stash:RemoveAndCleanup(CLICK_CONNECTION_KEY)

	if self._stash:Has(OWNED_DETECTOR_KEY) then
		self._stash:RemoveAndCleanup(OWNED_DETECTOR_KEY)
		self._detector = nil
	end

	self._manager:_ForgetHandle(self._target, self)
	return true
end

function Handle:Destroy(): ()
	if self._isDestroyed then
		return
	end

	if self._stateMachine:GetState() ~= Enums.HandleState.Destroyed then
		local transitionResult = Policies.CheckHandleTransition(self, Enums.HandleState.Destroyed)
		if transitionResult.success then
			self._stateMachine:Transition(Enums.HandleState.Destroyed)
		end
	end

	self._manager:_ForgetHandle(self._target, self)
	self._isDestroyed = true
	self._stash:Destroy()

	if self._detector ~= nil and self._detector.Parent == nil then
		self._detector = nil
	end
end

return table.freeze(Handle)
