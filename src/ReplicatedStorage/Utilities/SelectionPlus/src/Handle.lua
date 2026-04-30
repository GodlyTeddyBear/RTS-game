--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)

local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)
local Visuals = require(script.Parent.Visuals)

type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
type TSelectionHandle = Types.TSelectionHandle
type TSelectionRequest = Types.TSelectionRequest
type TSelectionState = Types.TSelectionState

--[=[
    @class SelectionPlusHandle
    Owns the visuals and lifecycle state for one active selection channel.
    @client
]=]
local Handle = {}
Handle.__index = Handle

local TRANSITIONS: { [TSelectionState]: { [TSelectionState]: boolean } } = {
	Idle = {
		Active = true,
		Destroyed = true,
	},
	Active = {
		Cleared = true,
		Destroyed = true,
	},
	Cleared = {
		Destroyed = true,
	},
	Destroyed = {},
}

--[=[
    Creates a handle for one active channel selection and its visuals.
    @within SelectionPlusHandle
    @param channelName string -- Owning selection channel.
    @param target TResolvedSelectionTarget -- Resolved selection target.
    @param request TSelectionRequest -- Normalized selection request.
    @param parent Instance -- Runtime visual parent.
    @return TSelectionHandle -- The new selection handle.
]=]
function Handle.new(
	channelName: string,
	target: TResolvedSelectionTarget,
	request: TSelectionRequest,
	parent: Instance
): TSelectionHandle
	Validation.AssertChannelName(channelName)
	Validation.AssertResolvedTarget(target)

	local self = setmetatable({}, Handle)
	self.Channel = channelName
	self.Target = target
	self.Metadata = request.Metadata
	self._janitor = Janitor.new()
	self._destroyed = false

	self.StateMachine = StateMachine.new({
		InitialState = "Idle",
		Transitions = TRANSITIONS,
		ErrorType = "IllegalSelectionHandleTransition",
		ErrorMessage = "Selection handle transition is not allowed",
	})
	self._janitor:Add(self.StateMachine, "Destroy")

	-- Enter the active state before visuals are created so downstream listeners see a live handle.
	self.StateMachine:Transition("Active")

	-- Create the configured visuals and register their cleanup with this handle's Janitor.
	Visuals.BuildSelectionVisuals(request, target, parent, self._janitor)

	return self :: any
end

--[=[
    Destroys the handle and all resources created for its channel.
    @within SelectionPlusHandle
]=]
function Handle:Destroy()
	if self._destroyed then
		return
	end

	-- Transition through the cleared state before final teardown so lifecycle listeners can react cleanly.
	if self.StateMachine:GetState() == "Active" then
		self.StateMachine:Transition("Cleared")
	end
	if self.StateMachine:GetState() ~= "Destroyed" then
		self.StateMachine:Transition("Destroyed")
	end

	self._destroyed = true
	self._janitor:Destroy()
end

--[=[
    Returns whether the handle has already been destroyed.
    @within SelectionPlusHandle
    @return boolean -- `true` when the handle is no longer active.
]=]
function Handle:IsDestroyed(): boolean
	return self._destroyed
end

return Handle
