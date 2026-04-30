--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local Handle = require(script.Handle)
local Resolver = require(script.Resolver)
local Types = require(script.Types)
local Validation = require(script.Validation)

export type TResolvedSelectionTarget = Types.TResolvedSelectionTarget
export type TSelectionHandle = Types.TSelectionHandle
export type TSelectionManager = Types.TSelectionManager
export type TSelectionManagerConfig = Types.TSelectionManagerConfig
export type TSelectionRequest = Types.TSelectionRequest
export type TSelectionResolverOptions = Types.TSelectionResolverOptions
export type THighlightConfig = Types.THighlightConfig
export type TRadiusConfig = Types.TRadiusConfig

--[=[
    @class SelectionPlusPackage
    Stateful client selection manager that owns one active handle per named channel.
    @client
]=]
local SelectionPlus = {}
SelectionPlus.__index = SelectionPlus

--[=[
    Creates a new `SelectionPlus` manager.
    @within SelectionPlusPackage
    @param config TSelectionManagerConfig? -- Optional manager configuration.
    @return TSelectionManager -- New manager instance.
]=]
function SelectionPlus.new(config: TSelectionManagerConfig?): TSelectionManager
	local self = setmetatable({}, SelectionPlus)
	self._janitor = Janitor.new()
	self._channels = {} :: { [string]: any }
	self._destroyed = false
	self._config = Validation.NormalizeManagerConfig(config)

	-- Create a dedicated runtime folder so built-in visuals can be cleaned up in one place.
	local visualParent = Instance.new("Folder")
	visualParent.Name = self._config.Name or "ClientSelectionPlus"
	visualParent.Parent = if self._config.Parent ~= nil then self._config.Parent else Workspace
	self._visualParent = visualParent
	self._janitor:Add(visualParent, "Destroy")

	return self :: any
end

--[=[
    Resolves a selection target from a camera screen point.
    @within SelectionPlusPackage
    @param camera Camera -- Camera used to build the cursor ray.
    @param screenPoint Vector2 -- Viewport-space cursor position.
    @param options TSelectionResolverOptions? -- Resolver options.
    @return TResolvedSelectionTarget? -- Resolved target, or `nil` when no valid target is found.
]=]
function SelectionPlus.ResolveTargetFromScreenPoint(
	camera: Camera,
	screenPoint: Vector2,
	options: TSelectionResolverOptions?
): TResolvedSelectionTarget?
	return Resolver.ResolveTargetFromScreenPoint(camera, screenPoint, options)
end

--[=[
    Selects a direct instance or resolved target into the requested channel.
    @within SelectionPlusPackage
    @param channelName string -- Channel to replace or populate.
    @param request TSelectionRequest -- Selection request payload.
    @return TSelectionHandle? -- New active handle, or `nil` when the request cannot resolve a valid target.
]=]
function SelectionPlus:Select(channelName: string, request: TSelectionRequest): TSelectionHandle?
	self:_AssertAlive()
	Validation.AssertChannelName(channelName)

	local normalizedRequest = Validation.NormalizeRequest(request, self._config)
	local resolvedTarget = Resolver.ResolveTarget(normalizedRequest.Target, normalizedRequest.ResolverOptions)
	if resolvedTarget == nil then
		return nil
	end

	-- Replace any existing handle in the same channel before constructing the new one.
	self:Clear(channelName)

	local handle = Handle.new(channelName, resolvedTarget, normalizedRequest, self._visualParent)
	self._channels[channelName] = handle
	return handle
end

--[=[
    Resolves a screen-point target and selects it into the requested channel.
    @within SelectionPlusPackage
    @param channelName string -- Channel to replace or populate.
    @param camera Camera -- Camera used to build the cursor ray.
    @param screenPoint Vector2 -- Viewport-space cursor position.
    @param request TSelectionRequest? -- Optional request overrides.
    @return TSelectionHandle? -- New active handle, or `nil` when the screen point does not resolve a valid target.
]=]
function SelectionPlus:SelectFromScreenPoint(
	channelName: string,
	camera: Camera,
	screenPoint: Vector2,
	request: TSelectionRequest?
): TSelectionHandle?
	self:_AssertAlive()
	Validation.AssertChannelName(channelName)

	local mutableRequest = Validation.CloneRequest(request)
	local resolvedTarget = Resolver.ResolveTargetFromScreenPoint(camera, screenPoint, mutableRequest.ResolverOptions)
	if resolvedTarget == nil then
		return nil
	end

	mutableRequest.Target = resolvedTarget
	return self:Select(channelName, mutableRequest)
end

--[=[
    Returns the active selection handle for a channel.
    @within SelectionPlusPackage
    @param channelName string -- Channel name to inspect.
    @return TSelectionHandle? -- Active handle, or `nil` when the channel is empty.
]=]
function SelectionPlus:GetSelection(channelName: string): TSelectionHandle?
	local handle = self._channels[channelName]
	if handle == nil then
		return nil
	end

	if handle:IsDestroyed() then
		self._channels[channelName] = nil
		return nil
	end

	return handle
end

--[=[
    Clears the active selection for one channel.
    @within SelectionPlusPackage
    @param channelName string -- Channel to clear.
]=]
function SelectionPlus:Clear(channelName: string)
	local handle = self._channels[channelName]
	if handle == nil then
		return
	end

	self._channels[channelName] = nil
	handle:Destroy()
end

--[=[
    Clears every active channel owned by the manager.
    @within SelectionPlusPackage
]=]
function SelectionPlus:ClearAll()
	local channelNames = {}
	for channelName in pairs(self._channels) do
		table.insert(channelNames, channelName)
	end

	for _, channelName in ipairs(channelNames) do
		self:Clear(channelName)
	end
end

--[=[
    Destroys the manager, all active handles, and the runtime visual folder.
    @within SelectionPlusPackage
]=]
function SelectionPlus:Destroy()
	if self._destroyed then
		return
	end

	self:ClearAll()
	self._destroyed = true
	self._janitor:Destroy()
end

function SelectionPlus:_AssertAlive()
	assert(not self._destroyed, "SelectionPlus manager has already been destroyed")
end

return table.freeze(SelectionPlus)
