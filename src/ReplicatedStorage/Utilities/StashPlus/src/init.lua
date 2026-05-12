--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)

local CleanupReport = require(script.CleanupReport)
local HelperMethods = require(script.Helpers)
local Resolution = require(script.Resolution)
local Types = require(script.Types)

type TAddOptions = Types.TAddOptions
type TMutableCleanupReport = CleanupReport.TMutableCleanupReport
type TCleanupMethod = Types.TCleanupMethod
type TCleanupReport = Types.TCleanupReport
type TStash = Types.TStash
type TStashPlus = Types.TStashPlus
type TStashState = Types.TStashState
type TTrackedMetadata = {
	Resource: any,
	CleanupMethod: TCleanupMethod?,
	Label: string?,
}

type TStashInternal = TStash & {
	_janitor: any,
	_trackedKeys: { [any]: any },
	_trackedMetadata: { [any]: TTrackedMetadata },
	_childStashes: { [string]: TStashInternal },
	_state: TStashState,
	_destroyReport: TCleanupReport?,
	_activeReport: TMutableCleanupReport?,
	_destroyRequested: boolean,
	_parent: TStashInternal?,
	_scopeName: string?,

	_AssertAlive: (self: TStashInternal) -> (),
	_AssertNotCleaning: (self: TStashInternal, operationName: string) -> (),
	_BeginCleanup: (self: TStashInternal) -> TMutableCleanupReport,
	_BuildCleanupTask: (
		self: TStashInternal,
		resource: any,
		cleanupMethod: TCleanupMethod?,
		label: string?,
		key: any?
	) -> () -> (),
	_EndCleanup: (self: TStashInternal, report: TMutableCleanupReport, shouldDestroy: boolean) -> TCleanupReport,
	_ForEachChild: (self: TStashInternal, callback: (string, TStashInternal) -> ()) -> (),
	_ForgetChild: (self: TStashInternal, childName: string, child: TStashInternal) -> (),
	_GetScopePath: (self: TStashInternal) -> string?,
	_NormalizeAddOptions: (
		self: TStashInternal,
		cleanupMethodOrOptions: (TCleanupMethod | TAddOptions)?,
		keyOrOptions: any?
	) -> (TCleanupMethod?, any?, string?),
	_RecordFailure: (
		self: TStashInternal,
		label: string?,
		key: any?,
		resource: any?,
		cleanupMethod: TCleanupMethod?,
		errorMessage: string
	) -> (),
	_SnapshotReport: (self: TStashInternal) -> TCleanupReport,
}

local EMPTY_REPORT = table.freeze({
	Success = true,
	FailureCount = 0,
	ResourceCountCleaned = 0,
	ScopeCountCleaned = 0,
	Failures = table.freeze({}),
	CleanedChildren = nil,
}) :: TCleanupReport

local StashPlus = {} :: TStashPlus & { [string]: any }
local StashMethods = {}
StashMethods.__index = StashMethods

local function _ApplyMethods(target: any, methods: { [string]: any })
	for methodName, method in pairs(methods) do
		target[methodName] = method
	end
end

local function _CreateStash(parent: TStashInternal?, scopeName: string?): TStashInternal
	local self = setmetatable({}, StashMethods) :: any
	self._janitor = Janitor.new()
	self._trackedKeys = {}
	self._trackedMetadata = {}
	self._childStashes = {}
	self._state = "Active"
	self._destroyReport = nil
	self._activeReport = nil
	self._destroyRequested = false
	self._parent = parent
	self._scopeName = scopeName
	return self
end

function StashPlus.new(): TStash
	return _CreateStash(nil, nil)
end

function StashPlus.Cleanup(resource: any, cleanupMethod: TCleanupMethod?): TCleanupReport
	local report = CleanupReport.new()
	local resolvedMethod = Resolution.ResolveMethod(resource, cleanupMethod)
	local ok, errorMessage = xpcall(function()
		Resolution.CleanupResource(resource, resolvedMethod)
	end, function(err)
		return tostring(err)
	end)

	if not ok then
		CleanupReport.RecordFailure(report, nil, nil, resource, resolvedMethod, errorMessage, nil, nil)
	else
		CleanupReport.RecordSuccess(report)
	end

	return CleanupReport.Finalize(report)
end

function StashPlus.CanCleanup(resource: any, cleanupMethod: TCleanupMethod?): (boolean, string?)
	return Resolution.CanCleanup(resource, cleanupMethod)
end

function StashPlus.ResolveCleanupMethod(resource: any, cleanupMethod: TCleanupMethod?): TCleanupMethod
	return Resolution.ResolveMethod(resource, cleanupMethod)
end

function StashMethods:Add(resource: any, cleanupMethodOrOptions: (TCleanupMethod | TAddOptions)?, keyOrOptions: any?): any
	self:_AssertAlive()
	self:_AssertNotCleaning("Add")
	assert(resource ~= nil, "StashPlus:Add requires a resource")

	local cleanupMethod, key, label = self:_NormalizeAddOptions(cleanupMethodOrOptions, keyOrOptions)
	local cleanupTask = self:_BuildCleanupTask(resource, cleanupMethod, label, key)
	self._janitor:Add(cleanupTask, true, key)

	if key ~= nil then
		self._trackedKeys[key] = resource
		self._trackedMetadata[key] = {
			Resource = resource,
			CleanupMethod = cleanupMethod,
			Label = label,
		}
	end

	return resource
end

function StashMethods:Has(key: any): boolean
	return self._trackedMetadata[key] ~= nil
end

function StashMethods:Count(): number
	local count = 0
	for _ in pairs(self._trackedKeys) do
		count += 1
	end
	return count
end

function StashMethods:Get(key: any): any?
	return self._trackedKeys[key]
end

function StashMethods:GetAll(): { [any]: any }
	return table.freeze(table.clone(self._trackedKeys))
end

function StashMethods:GetState(): TStashState
	return self._state
end

function StashMethods:IsCleaning(): boolean
	return self._state == "Cleaning"
end

function StashMethods:GetScope(name: string): TStash?
	local child = self._childStashes[name]
	if child == nil then
		return nil
	end

	if child:IsDestroyed() then
		self._childStashes[name] = nil
		return nil
	end

	return child
end

function StashMethods:GetScopeNames(): { string }
	local scopeNames = {}
	for scopeName, child in pairs(self._childStashes) do
		if child:IsDestroyed() then
			self._childStashes[scopeName] = nil
		else
			table.insert(scopeNames, scopeName)
		end
	end

	table.sort(scopeNames)
	return table.freeze(scopeNames)
end

function StashMethods:CountScopes(): number
	return #self:GetScopeNames()
end

function StashMethods:HasScope(name: string): boolean
	return self:GetScope(name) ~= nil
end

function StashMethods:Remove(key: any): boolean
	self:_AssertNotCleaning("Remove")

	local tracked = self._janitor:Get(key)
	if tracked == nil then
		return false
	end

	self._janitor:Remove(key)
	self._trackedKeys[key] = nil
	self._trackedMetadata[key] = nil
	return true
end

function StashMethods:RemoveAndCleanup(key: any): TCleanupReport
	self:_AssertNotCleaning("RemoveAndCleanup")

	local metadata = self._trackedMetadata[key]
	if metadata == nil then
		return EMPTY_REPORT
	end

	self._janitor:Remove(key)
	self._trackedKeys[key] = nil
	self._trackedMetadata[key] = nil

	local report = CleanupReport.new()
	local resolvedMethod = Resolution.ResolveMethod(metadata.Resource, metadata.CleanupMethod)
	local ok, errorMessage = xpcall(function()
		Resolution.CleanupResource(metadata.Resource, resolvedMethod)
	end, function(err)
		return tostring(err)
	end)

	if not ok then
		CleanupReport.RecordFailure(
			report,
			metadata.Label,
			key,
			metadata.Resource,
			resolvedMethod,
			errorMessage,
			self._scopeName,
			self:_GetScopePath()
		)
	else
		CleanupReport.RecordSuccess(report)
	end

	return CleanupReport.Finalize(report)
end

function StashMethods:Scope(name: string): TStash
	self:_AssertAlive()
	self:_AssertNotCleaning("Scope")
	assert(type(name) == "string" and name ~= "", "StashPlus:Scope requires a non-empty name")

	local existing = self:GetScope(name)
	if existing ~= nil then
		return existing
	end

	local child = _CreateStash(self, name)
	self._childStashes[name] = child
	return child
end

function StashMethods:RemoveScope(name: string): boolean
	self:_AssertNotCleaning("RemoveScope")

	local child = self:GetScope(name) :: TStashInternal?
	if child == nil then
		return false
	end

	self._childStashes[name] = nil
	child._parent = nil
	child._scopeName = nil
	return true
end

function StashMethods:DestroyScope(name: string): TCleanupReport
	self:_AssertNotCleaning("DestroyScope")

	local child = self:GetScope(name)
	if child == nil then
		return EMPTY_REPORT
	end

	return child:Destroy()
end

function StashMethods:DestroyAllScopes(): TCleanupReport
	self:_AssertNotCleaning("DestroyAllScopes")

	local report = CleanupReport.new()
	for _, childName in ipairs(self:GetScopeNames()) do
		local child = self._childStashes[childName]
		if child ~= nil and not child:IsDestroyed() then
			CleanupReport.RecordChild(report, childName)
			CleanupReport.Merge(report, child:Destroy())
		end
	end

	return CleanupReport.Finalize(report)
end

function StashMethods:Cleanup(): TCleanupReport
	if self._state == "Destroyed" then
		return self._destroyReport or EMPTY_REPORT
	end
	if self._state == "Cleaning" then
		return self:_SnapshotReport()
	end

	local report = self:_BeginCleanup()

	self:_ForEachChild(function(childName: string, child: TStashInternal)
		if child:IsDestroyed() then
			return
		end

		CleanupReport.RecordChild(report, childName)
		CleanupReport.Merge(report, child:Cleanup())
	end)

	self._janitor:Cleanup()
	table.clear(self._trackedKeys)
	table.clear(self._trackedMetadata)

	return self:_EndCleanup(report, self._destroyRequested)
end

function StashMethods:Destroy(): TCleanupReport
	if self._state == "Destroyed" then
		return self._destroyReport or EMPTY_REPORT
	end
	if self._state == "Cleaning" then
		self._destroyRequested = true
		return self:_SnapshotReport()
	end

	local report = self:_BeginCleanup()
	self._destroyRequested = true

	self:_ForEachChild(function(childName: string, child: TStashInternal)
		if child:IsDestroyed() then
			return
		end

		CleanupReport.RecordChild(report, childName)
		CleanupReport.Merge(report, child:Destroy())
	end)

	self._janitor:Cleanup()
	table.clear(self._trackedKeys)
	table.clear(self._trackedMetadata)

	return self:_EndCleanup(report, true)
end

function StashMethods:IsDestroyed(): boolean
	return self._state == "Destroyed"
end

function StashMethods:_AssertAlive()
	assert(self._state ~= "Destroyed", "StashPlus has already been destroyed")
end

function StashMethods:_AssertNotCleaning(operationName: string)
	assert(self._state ~= "Cleaning", string.format("StashPlus:%s is not allowed during cleanup", operationName))
end

function StashMethods:_BuildCleanupTask(resource: any, cleanupMethod: TCleanupMethod?, label: string?, key: any?): () -> ()
	return function()
		local resolvedMethod = Resolution.ResolveMethod(resource, cleanupMethod)
		local ok, errorMessage = xpcall(function()
			Resolution.CleanupResource(resource, resolvedMethod)
		end, function(err)
			return tostring(err)
		end)

		if ok then
			local activeReport = self._activeReport
			if activeReport ~= nil then
				CleanupReport.RecordSuccess(activeReport)
			end
			return
		end

		self:_RecordFailure(label, key, resource, resolvedMethod, errorMessage)
	end
end

function StashMethods:_NormalizeAddOptions(
	cleanupMethodOrOptions: (TCleanupMethod | TAddOptions)?,
	keyOrOptions: any?
): (TCleanupMethod?, any?, string?)
	local cleanupMethod = nil :: TCleanupMethod?
	local key = nil
	local label = nil :: string?

	if type(cleanupMethodOrOptions) == "table" then
		local options = cleanupMethodOrOptions :: TAddOptions
		cleanupMethod = options.CleanupMethod
		key = options.Key
		label = options.Label
	elseif cleanupMethodOrOptions ~= nil then
		assert(
			type(cleanupMethodOrOptions) == "string" or type(cleanupMethodOrOptions) == "boolean",
			"StashPlus:Add cleanupMethod must be a string, boolean, or options table"
		)
		cleanupMethod = cleanupMethodOrOptions :: TCleanupMethod
	end

	if type(keyOrOptions) == "table" then
		local options = keyOrOptions :: TAddOptions
		if cleanupMethod == nil then
			cleanupMethod = options.CleanupMethod
		end
		if key == nil then
			key = options.Key
		end
		if label == nil then
			label = options.Label
		end
	elseif keyOrOptions ~= nil then
		assert(key == nil, "StashPlus:Add key was provided twice")
		key = keyOrOptions
	end

	if label == nil and key ~= nil then
		label = tostring(key)
	end

	return cleanupMethod, key, label
end

function StashMethods:_BeginCleanup(): TMutableCleanupReport
	local report = CleanupReport.new()
	self._state = "Cleaning"
	self._activeReport = report
	return report
end

function StashMethods:_EndCleanup(report: TMutableCleanupReport, shouldDestroy: boolean): TCleanupReport
	self._activeReport = nil

	local finalizedReport = CleanupReport.Finalize(report)
	local willDestroy = shouldDestroy or self._destroyRequested
	self._destroyRequested = false

	if willDestroy then
		self._state = "Destroyed"
		self._destroyReport = finalizedReport
		table.clear(self._trackedKeys)
		table.clear(self._trackedMetadata)
		table.clear(self._childStashes)

		local parent = self._parent
		if parent ~= nil and self._scopeName ~= nil then
			parent:_ForgetChild(self._scopeName, self)
		end

		self._parent = nil
		self._scopeName = nil
		return finalizedReport
	end

	self._state = "Active"
	return finalizedReport
end

function StashMethods:_ForEachChild(callback: (string, TStashInternal) -> ())
	local childNames = {}
	for childName in pairs(self._childStashes) do
		table.insert(childNames, childName)
	end

	table.sort(childNames)

	for _, childName in ipairs(childNames) do
		local child = self._childStashes[childName]
		if child ~= nil then
			callback(childName, child)
		end
	end
end

function StashMethods:_ForgetChild(childName: string, child: TStashInternal)
	if self._childStashes[childName] ~= child then
		return
	end

	self._childStashes[childName] = nil
end

function StashMethods:_RecordFailure(
	label: string?,
	key: any?,
	resource: any?,
	cleanupMethod: TCleanupMethod?,
	errorMessage: string
)
	local activeReport = self._activeReport
	if activeReport ~= nil then
		CleanupReport.RecordFailure(
			activeReport,
			label,
			key,
			resource,
			cleanupMethod,
			errorMessage,
			self._scopeName,
			self:_GetScopePath()
		)
		return
	end

	warn(string.format("[StashPlus] Cleanup failed%s: %s", if label ~= nil then " for " .. label else "", errorMessage))
end

function StashMethods:_GetScopePath(): string?
	if self._scopeName == nil then
		return nil
	end

	local pathSegments = { self._scopeName }
	local cursor = self._parent

	while cursor ~= nil do
		if cursor._scopeName ~= nil then
			table.insert(pathSegments, 1, cursor._scopeName)
		end
		cursor = cursor._parent
	end

	return table.concat(pathSegments, "/")
end

function StashMethods:_SnapshotReport(): TCleanupReport
	local activeReport = self._activeReport
	if activeReport == nil then
		return self._destroyReport or EMPTY_REPORT
	end

	return CleanupReport.Finalize(activeReport)
end

_ApplyMethods(StashMethods, HelperMethods)

StashPlus.ResolveMethod = Resolution.ResolveMethod

return table.freeze(StashPlus)
