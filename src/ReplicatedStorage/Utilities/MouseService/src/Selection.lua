--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)

local Enums = require(script.Parent.Enums)
local Errors = require(script.Parent.Errors)
local Options = require(script.Parent.Options)
local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type TMouseSelectionRequest = Types.TMouseSelectionRequest
type TMouseSelectionSnapshot = Types.TMouseSelectionSnapshot
type TResolvedMouseSelectionRequest = Types.TResolvedMouseSelectionRequest
type TResolvedMouseSelectionResult = {
	ResolvedRequest: TResolvedMouseSelectionRequest,
	MouseSnapshot: Types.TMouseSnapshot,
}

local SELECTION_SCOPE_PREFIX = "selection:"
local MIRROR_SELECTION_CLEAR_KEY = "MirrorSelectionClear"

local Selection = {}

local function _BuildScopeKey(channelName: string): string
	return SELECTION_SCOPE_PREFIX .. channelName
end

local function _CreateSelectionSnapshot(
	channelName: string,
	resolvedRequest: TResolvedMouseSelectionRequest,
	mouseSnapshot: Types.TMouseSnapshot,
	mirrored: boolean
): TMouseSelectionSnapshot
	return table.freeze({
		Channel = channelName,
		Mode = Enums.SelectionMode.Single,
		MouseSnapshot = mouseSnapshot,
		Target = mouseSnapshot.ResolvedTarget :: SelectionPlus.TResolvedSelectionTarget,
		Metadata = resolvedRequest.Metadata,
		Mirrored = mirrored,
	})
end

local function _GetOrCreateSelectionManager(manager: any): any
	if manager._selectionManager ~= nil then
		return manager._selectionManager
	end

	local selectionManager = SelectionPlus.new({
		Parent = manager._config.SelectionParent,
		Name = "MouseServiceSelection",
		DefaultHighlight = manager._config.DefaultSelectionHighlight,
		DefaultRadius = manager._config.DefaultSelectionRadius,
	})
	manager._selectionManager = selectionManager
	manager._stash:Add(selectionManager, {
		CleanupMethod = "Destroy",
		Key = "SelectionManager",
		Label = "SelectionManager",
	})
	return selectionManager
end

local function _ShouldMirrorSelection(manager: any, resolvedRequest: TResolvedMouseSelectionRequest): boolean
	if resolvedRequest.MirrorSelection then
		return true
	end

	return resolvedRequest.Highlight ~= nil or resolvedRequest.Radius ~= nil or manager._config.MirrorSelections == true
end

local function _ResolveMouseSelection(
	manager: any,
	channelName: string,
	request: TMouseSelectionRequest?
): Result.Result<TResolvedMouseSelectionResult>
	local requestResult = Policies.CheckSelectionRequest(request)
	if not requestResult.success then
		return requestResult
	end

	local resolvedRequest = Options.ResolveSelectionRequest(manager._config, request)
	local mouseSnapshotResult = manager:ResolveSnapshot(resolvedRequest)
	if not mouseSnapshotResult.success then
		return mouseSnapshotResult
	end

	local mouseSnapshot = mouseSnapshotResult.value
	if mouseSnapshot.ResolvedTarget == nil then
		local errorType, message, data = Errors.BuildSelectionTargetNotFound(channelName)
		return Result.Err(errorType, message, data)
	end

	return Result.Ok({
		ResolvedRequest = resolvedRequest,
		MouseSnapshot = mouseSnapshot,
	})
end

function Selection.SetSelection(
	manager: any,
	channelName: string,
	request: TMouseSelectionRequest?
): Result.Result<TMouseSelectionSnapshot>
	local resolvedSelectionResult = _ResolveMouseSelection(manager, channelName, request)
	if not resolvedSelectionResult.success then
		return resolvedSelectionResult
	end

	local resolvedSelection = resolvedSelectionResult.value
	local resolvedRequest = resolvedSelection.ResolvedRequest
	local mouseSnapshot = resolvedSelection.MouseSnapshot
	local previousSnapshot = manager._selectionStateByChannel[channelName]

	manager:ClearSelection(channelName)

	local mirrored = false
	local scope = manager._stash:Scope(_BuildScopeKey(channelName))
	if _ShouldMirrorSelection(manager, resolvedRequest) then
		local selectionManager = _GetOrCreateSelectionManager(manager)
		selectionManager:SetSelection(channelName, {
			Target = mouseSnapshot.ResolvedTarget,
			Highlight = resolvedRequest.Highlight,
			Radius = resolvedRequest.Radius,
			Metadata = resolvedRequest.Metadata,
		})
		scope:AddCallback(MIRROR_SELECTION_CLEAR_KEY, function()
			selectionManager:Clear(channelName)
		end, {
			Key = MIRROR_SELECTION_CLEAR_KEY,
			Label = MIRROR_SELECTION_CLEAR_KEY,
		})
		mirrored = true
	end

	local snapshot = _CreateSelectionSnapshot(channelName, resolvedRequest, mouseSnapshot, mirrored)
	manager._selectionStateByChannel[channelName] = snapshot
	manager.SelectionChanged:Fire(channelName, snapshot, previousSnapshot)
	return Result.Ok(snapshot)
end

function Selection.SetSelectionFromCurrentMouse(
	manager: any,
	channelName: string,
	request: TMouseSelectionRequest?
): Result.Result<TMouseSelectionSnapshot>
	local clonedRequest = Options.CreateSelectionRequest(request)
	clonedRequest.ScreenPoint = nil
	return Selection.SetSelection(manager, channelName, clonedRequest)
end

function Selection.ClearSelection(manager: any, channelName: string): Result.Result<TMouseSelectionSnapshot?>
	local previousSnapshot = manager._selectionStateByChannel[channelName]
	if previousSnapshot == nil then
		return Result.Ok(nil)
	end

	manager._selectionStateByChannel[channelName] = nil
	if manager._stash:HasScope(_BuildScopeKey(channelName)) then
		manager._stash:DestroyScope(_BuildScopeKey(channelName))
	end

	manager.SelectionCleared:Fire(channelName, previousSnapshot)
	return Result.Ok(previousSnapshot)
end

function Selection.ClearAllSelections(manager: any)
	local channelNames = {}
	for channelName in pairs(manager._selectionStateByChannel) do
		channelNames[#channelNames + 1] = channelName
	end

	for _, channelName in ipairs(channelNames) do
		Selection.ClearSelection(manager, channelName)
	end
end

return table.freeze(Selection)
