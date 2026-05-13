--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StashPlus = require(ReplicatedStorage.Utilities.StashPlus)

local Enums = require(script.Parent.Enums)
local Handle = require(script.Parent.Handle)
local Policies = require(script.Parent.Policies)
local Resolver = require(script.Parent.Resolver)
local Signals = require(script.Parent.Signals)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TInvalidationReason = Types.TInvalidationReason
type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
type TSelectionHandle = Types.TSelectionHandle
type TSelectionManager = Types.TSelectionManager
type TSelectionRequest = Types.TSelectionRequest
type TSelectionSetRequest = Types.TSelectionSetRequest

local SELECTION_CHANGED_SIGNAL_KEY = "SelectionChanged"
local SELECTION_CLEARED_SIGNAL_KEY = "SelectionCleared"
local SELECTION_INVALIDATED_SIGNAL_KEY = "SelectionInvalidated"
local VISUAL_PARENT_KEY = "VisualParent"

local Manager = {}
Manager.__index = Manager

function Manager.new(config: Types.TSelectionManagerConfig?): TSelectionManager
	Policies.CheckConfig(config)

	local self = setmetatable({}, Manager) :: any
	self._config = Validation.NormalizeManagerConfig(config)
	self._handlesByChannel = {} :: { [string]: TSelectionHandle }
	self._stash = StashPlus.new()
	self._isDestroyed = false
	self.SelectionChanged = Signals.Create(self._stash, SELECTION_CHANGED_SIGNAL_KEY)
	self.SelectionCleared = Signals.Create(self._stash, SELECTION_CLEARED_SIGNAL_KEY)
	self.SelectionInvalidated = Signals.Create(self._stash, SELECTION_INVALIDATED_SIGNAL_KEY)

	local visualParent = Instance.new("Folder")
	visualParent.Name = self._config.Name
	visualParent.Parent = if self._config.Parent ~= nil then self._config.Parent else Workspace
	self._visualParent = visualParent
	self._stash:AddInstance(visualParent, {
		Key = VISUAL_PARENT_KEY,
		Label = VISUAL_PARENT_KEY,
	})

	return self
end

function Manager:SetSelection(channelName: string, request: TSelectionRequest): TSelectionHandle?
	Policies.CheckServiceAlive(self)
	Policies.CheckChannelName(channelName)
	Policies.CheckRequest(request)
	Policies.CheckTarget(if request ~= nil then request.Target else nil)

	local resolvedRequest = Validation.ResolveRequest(self._config, request)
	local resolvedTarget = Resolver.ResolveTarget(resolvedRequest.Target, resolvedRequest.ResolverOptions)
	if resolvedTarget == nil then
		return nil
	end

	return self:_SetResolvedTargets(channelName, { resolvedTarget }, Enums.SelectionMode.Single, resolvedRequest)
end

function Manager:SetSelectionSet(channelName: string, request: TSelectionSetRequest): TSelectionHandle?
	Policies.CheckServiceAlive(self)
	Policies.CheckChannelName(channelName)
	Policies.CheckSetRequest(request)

	local resolvedRequest = Validation.ResolveSetRequest(self._config, request)
	local resolvedTargets = {}
	for _, target in ipairs(resolvedRequest.Targets) do
		local resolvedTarget = Resolver.ResolveTarget(target, resolvedRequest.ResolverOptions)
		if resolvedTarget ~= nil then
			table.insert(resolvedTargets, resolvedTarget)
		end
	end

	if #resolvedTargets == 0 then
		return nil
	end

	return self:_SetResolvedTargets(channelName, resolvedTargets, Enums.SelectionMode.Set, resolvedRequest)
end

function Manager:ResolveAndSetFromScreenPoint(
	channelName: string,
	camera: Camera,
	screenPoint: Vector2,
	request: TSelectionRequest?
): TSelectionHandle?
	Policies.CheckServiceAlive(self)
	Policies.CheckChannelName(channelName)
	Policies.CheckRequest(request)

	local mutableRequest = Validation.CloneRequest(request)
	local resolvedRequest = Validation.ResolveRequest(self._config, mutableRequest)
	local resolvedTarget = Resolver.ResolveTargetFromScreenPoint(camera, screenPoint, resolvedRequest.ResolverOptions)
	if resolvedTarget == nil then
		return nil
	end

	return self:_SetResolvedTargets(channelName, { resolvedTarget }, Enums.SelectionMode.Single, resolvedRequest)
end

function Manager:GetHandle(channelName: string): TSelectionHandle?
	Policies.CheckChannelName(channelName)

	local handle = self._handlesByChannel[channelName]
	if handle == nil then
		return nil
	end

	if handle:GetState() == Enums.HandleState.Destroyed then
		self._handlesByChannel[channelName] = nil
		return nil
	end

	return handle
end

function Manager:GetSnapshot(channelName: string): Types.TSelectionSnapshot?
	local handle = self:GetHandle(channelName)
	if handle == nil then
		return nil
	end

	return handle:GetSnapshot()
end

function Manager:GetPrimaryTarget(channelName: string): TResolvedSelectionTarget?
	return Validation.ResolvePrimaryTarget(self:GetSnapshot(channelName))
end

function Manager:HasSelection(channelName: string): boolean
	return self:GetHandle(channelName) ~= nil
end

function Manager:GetSelectionCount(channelName: string): number
	local snapshot = self:GetSnapshot(channelName)
	if snapshot == nil then
		return 0
	end

	return #snapshot.Entries
end

function Manager:Clear(channelName: string)
	Policies.CheckServiceAlive(self)
	Policies.CheckChannelName(channelName)
	self:_ClearChannel(channelName, Enums.InvalidationReason.CallerCleared)
end

function Manager:ClearAll()
	Policies.CheckServiceAlive(self)
	local channelNames = {}
	for channelName in pairs(self._handlesByChannel) do
		table.insert(channelNames, channelName)
	end

	for _, channelName in ipairs(channelNames) do
		self:_ClearChannel(channelName, Enums.InvalidationReason.CallerCleared)
	end
end

function Manager:Destroy()
	if self._isDestroyed then
		return
	end

	self:ClearAll()
	self._isDestroyed = true
	table.clear(self._handlesByChannel)
	self._stash:Destroy()
end

function Manager:Select(channelName: string, request: TSelectionRequest): TSelectionHandle?
	return self:SetSelection(channelName, request)
end

function Manager:SelectFromScreenPoint(
	channelName: string,
	camera: Camera,
	screenPoint: Vector2,
	request: TSelectionRequest?
): TSelectionHandle?
	return self:ResolveAndSetFromScreenPoint(channelName, camera, screenPoint, request)
end

function Manager:GetSelection(channelName: string): TSelectionHandle?
	return self:GetHandle(channelName)
end

function Manager:_SetResolvedTargets(
	channelName: string,
	resolvedTargets: { TResolvedSelectionTarget },
	mode: any,
	resolvedRequest: any
): TSelectionHandle
	local previousSnapshot = self:GetSnapshot(channelName)

	self:_ClearChannel(channelName, Enums.InvalidationReason.CallerCleared, true)

	local snapshot = Validation.CreateSnapshot(channelName, mode, resolvedTargets, resolvedRequest.Metadata)
	local channelScope = self._stash:Scope(channelName)
	local handle = Handle.new(self, channelName, snapshot, resolvedRequest, self._visualParent, channelScope)
	self._handlesByChannel[channelName] = handle
	self.SelectionChanged:Fire(channelName, snapshot, previousSnapshot)
	return handle
end

function Manager:_ClearChannel(channelName: string, reason: TInvalidationReason, suppressSignals: boolean?)
	local handle = self._handlesByChannel[channelName]
	if handle == nil then
		if self._stash:HasScope(channelName) then
			self._stash:DestroyScope(channelName)
		end
		return
	end

	local previousSnapshot = handle:GetSnapshot()
	self._handlesByChannel[channelName] = nil
	handle:_ClearWithReason(reason)

	if suppressSignals then
		return
	end

	if reason == Enums.InvalidationReason.CallerCleared then
		self.SelectionCleared:Fire(channelName, previousSnapshot, reason)
	else
		self.SelectionInvalidated:Fire(channelName, previousSnapshot, reason)
	end
end

function Manager:_HandleInvalidated(handle: TSelectionHandle, reason: TInvalidationReason)
	self:_ClearChannel(handle.Channel, reason)
end

return table.freeze(Manager)
