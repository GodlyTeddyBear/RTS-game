--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local Enums = require(script.Parent.Enums)
local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)
local Visuals = require(script.Parent.Visuals)

type TInvalidationReason = Types.TInvalidationReason
type TSelectionHandle = Types.TSelectionHandle
type TSelectionHandleState = Types.TSelectionHandleState
type TSelectionSnapshot = Types.TSelectionSnapshot

local STATE_MACHINE_KEY = "StateMachine"
local VISUAL_SCOPE_NAME = "Visuals"
local INVALIDATION_SCOPE_NAME = "Invalidation"
local CHANNEL_FOLDER_KEY = "ChannelFolder"

local TRANSITIONS: { [TSelectionHandleState]: { [TSelectionHandleState]: boolean } } = {
	[Enums.HandleState.Active] = {
		[Enums.HandleState.Cleared] = true,
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Cleared] = {
		[Enums.HandleState.Destroyed] = true,
	},
	[Enums.HandleState.Destroyed] = {},
}

local Handle = {}
Handle.__index = Handle

function Handle.new(
	manager: any,
	channelName: string,
	snapshot: TSelectionSnapshot,
	request: any,
	visualParent: Instance,
	stash: any
): TSelectionHandle
	local self = setmetatable({}, Handle) :: any
	self._manager = manager
	self._stash = stash
	self._snapshot = snapshot
	self._isDestroyed = false
	self._lastReason = nil :: TInvalidationReason?
	self.Channel = channelName
	self.Target = if snapshot.PrimaryEntry ~= nil then snapshot.PrimaryEntry.Target else nil
	self.Metadata = snapshot.Metadata
	self._stateMachine = StateMachine.new({
		InitialState = Enums.HandleState.Active,
		Transitions = TRANSITIONS,
		ErrorType = Enums.ErrorKey.IllegalSelectionHandleTransition.Name,
		ErrorMessage = Enums.ErrorMessage[Enums.ErrorKey.IllegalSelectionHandleTransition],
		ErrorDataBuilder = function(fromState: TSelectionHandleState, toState: TSelectionHandleState)
			return {
				From = fromState.Name,
				To = toState.Name,
			}
		end,
	})
	self.StateChanged = self._stateMachine.StateChanged

	self._stash:Add(self._stateMachine, {
		CleanupMethod = "Destroy",
		Key = STATE_MACHINE_KEY,
		Label = STATE_MACHINE_KEY,
	})

	local visualsScope = self._stash:Scope(VISUAL_SCOPE_NAME)
	local channelFolder = Instance.new("Folder")
	channelFolder.Name = channelName
	channelFolder.Parent = visualParent
	visualsScope:AddInstance(channelFolder, {
		Key = CHANNEL_FOLDER_KEY,
		Label = CHANNEL_FOLDER_KEY,
	})
	Visuals.BuildSelectionVisuals(snapshot, request.Highlight, request.Radius, channelFolder, visualsScope)

	self:_ConnectInvalidationWatchers()

	return self
end

function Handle:GetSnapshot(): TSelectionSnapshot
	return self._snapshot
end

function Handle:GetState(): TSelectionHandleState
	return self._stateMachine:GetState()
end

function Handle:IsActive(): boolean
	return self._stateMachine:GetState() == Enums.HandleState.Active
end

function Handle:Clear()
	if self._isDestroyed then
		return
	end

	self._manager:Clear(self.Channel)
end

function Handle:Destroy()
	if self._isDestroyed then
		return
	end

	self._manager:Clear(self.Channel)
end

function Handle:_ClearWithReason(reason: TInvalidationReason)
	if self._isDestroyed then
		return
	end

	local currentState = self._stateMachine:GetState()
	if currentState == Enums.HandleState.Active then
		Policies.CheckHandleTransition(self, Enums.HandleState.Cleared)
		self._stateMachine:Transition(Enums.HandleState.Cleared)
	end

	if self._stateMachine:GetState() ~= Enums.HandleState.Destroyed then
		Policies.CheckHandleTransition(self, Enums.HandleState.Destroyed)
		self._stateMachine:Transition(Enums.HandleState.Destroyed)
	end

	self._lastReason = reason
	self._isDestroyed = true
	self._stash:Destroy()
end

function Handle:_ConnectInvalidationWatchers()
	local invalidationScope = self._stash:Scope(INVALIDATION_SCOPE_NAME)
	local watchedInstances = {}

	for _, entry in ipairs(self._snapshot.Entries) do
		local root = entry.Target.Root
		local adornee = entry.Target.Adornee

		for _, instance in ipairs({ root, adornee }) do
			if watchedInstances[instance] ~= true then
				watchedInstances[instance] = true
				invalidationScope:AddConnection(instance.Destroying:Connect(function()
					if not self:IsActive() then
						return
					end

					local reason = if instance == root
						then Enums.InvalidationReason.TargetDestroyed
						else Enums.InvalidationReason.AdorneeInvalid
					self._manager:_HandleInvalidated(self, reason)
				end))
			end
		end
	end
end

return table.freeze(Handle)
