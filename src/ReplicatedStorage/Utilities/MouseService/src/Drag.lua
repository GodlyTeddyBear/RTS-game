--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)

local Enums = require(script.Parent.Enums)
local Errors = require(script.Parent.Errors)
local Marquee = require(script.Parent.Marquee)
local Options = require(script.Parent.Options)
local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type TMarqueeTargetEntry = Types.TMarqueeTargetEntry
type TMouseDragRequest = Types.TMouseDragRequest
type TMouseDragSnapshot = Types.TMouseDragSnapshot
type TResolvedMouseDragRequest = Types.TResolvedMouseDragRequest
type TMouseSnapshot = Types.TMouseSnapshot
type TResolvedMouseDragResult = {
	ResolvedRequest: TResolvedMouseDragRequest,
	MouseSnapshot: TMouseSnapshot,
}
type TDragSession = {
	Request: TResolvedMouseDragRequest,
	Snapshot: TMouseDragSnapshot,
}

local DRAG_SCOPE_PREFIX = "drag:"
local DRAG_PREVIEW_SELECTION_KEY = "DragPreviewSelectionClear"
local DRAG_PREVIEW_SELECTION_MANAGER_KEY = "DragPreviewSelectionManager"
local DRAG_PREVIEW_CHANNEL_PREFIX = "__mouse_marquee_preview__:"

local Drag = {}

local function _BuildScopeKey(channelName: string): string
	return DRAG_SCOPE_PREFIX .. channelName
end

local function _BuildPreviewSelectionChannelName(channelName: string, request: TResolvedMouseDragRequest): string
	local previewChannel = if request.PreviewSelectionChannel ~= nil then request.PreviewSelectionChannel else channelName
	return DRAG_PREVIEW_CHANNEL_PREFIX .. previewChannel
end

local function _GetOrCreatePreviewSelectionManager(manager: any): any
	if manager._dragPreviewSelectionManager ~= nil then
		return manager._dragPreviewSelectionManager
	end

	local selectionManager = SelectionPlus.new({
		Parent = manager._config.SelectionParent,
		Name = "MouseServiceMarqueePreview",
		DefaultHighlight = manager._config.DefaultSelectionHighlight,
		DefaultRadius = manager._config.DefaultSelectionRadius,
	})
	manager._dragPreviewSelectionManager = selectionManager
	manager._stash:Add(selectionManager, {
		CleanupMethod = "Destroy",
		Key = DRAG_PREVIEW_SELECTION_MANAGER_KEY,
		Label = DRAG_PREVIEW_SELECTION_MANAGER_KEY,
	})
	return selectionManager
end

local function _GetSession(manager: any, channelName: string): TDragSession?
	return manager._dragStateByChannel[channelName]
end

local function _GetSnapshot(manager: any, channelName: string): TMouseDragSnapshot?
	local session = _GetSession(manager, channelName)
	if session == nil then
		return nil
	end

	return session.Snapshot
end

local function _BuildDragSnapshot(
	channelName: string,
	mode: Types.TMouseDragMode,
	state: Types.TMouseDragState,
	endReason: Types.TMouseDragEndReason?,
	startSnapshot: TMouseSnapshot,
	currentSnapshot: TMouseSnapshot,
	endSnapshot: TMouseSnapshot?,
	metadata: { [string]: any }?,
	normalizedScreenRect: Types.TScreenRect?,
	previewTargets: { TMarqueeTargetEntry }?,
	previewMirrored: boolean?
): TMouseDragSnapshot
	local currentWorldPoint = currentSnapshot.WorldPoint
	local startWorldPoint = startSnapshot.WorldPoint
	local endWorldPoint = if endSnapshot ~= nil then endSnapshot.WorldPoint else nil
	local worldDelta = if currentWorldPoint ~= nil and startWorldPoint ~= nil
		then currentWorldPoint - startWorldPoint
		else nil

	return table.freeze({
		Channel = channelName,
		Mode = mode,
		State = state,
		EndReason = endReason,
		StartSnapshot = startSnapshot,
		CurrentSnapshot = currentSnapshot,
		EndSnapshot = endSnapshot,
		StartWorldPoint = startWorldPoint,
		CurrentWorldPoint = currentWorldPoint,
		EndWorldPoint = endWorldPoint,
		StartProjectedWorldPoint = startSnapshot.ProjectedWorldPoint,
		CurrentProjectedWorldPoint = currentSnapshot.ProjectedWorldPoint,
		EndProjectedWorldPoint = if endSnapshot ~= nil then endSnapshot.ProjectedWorldPoint else nil,
		ScreenDelta = currentSnapshot.ScreenPoint - startSnapshot.ScreenPoint,
		WorldDelta = worldDelta,
		NormalizedScreenRect = normalizedScreenRect,
		PreviewTargets = previewTargets,
		PreviewTargetCount = if previewTargets ~= nil then #previewTargets else nil,
		PreviewMirrored = previewMirrored,
		Metadata = metadata,
	})
end

local function _ResolveDragSnapshot(
	manager: any,
	request: TMouseDragRequest?
): Result.Result<TResolvedMouseDragResult>
	local requestResult = Policies.CheckDragRequest(request)
	if not requestResult.success then
		return requestResult
	end

	local resolvedRequest = Options.ResolveDragRequest(manager._config, request)
	local mouseSnapshotResult = manager:ResolveSnapshot(resolvedRequest)
	if not mouseSnapshotResult.success then
		return mouseSnapshotResult
	end

	return Result.Ok({
		ResolvedRequest = resolvedRequest,
		MouseSnapshot = mouseSnapshotResult.value,
	})
end

local function _ResolveWorldDragSnapshotOrErr(
	manager: any,
	channelName: string,
	request: TMouseDragRequest?
): Result.Result<TResolvedMouseDragResult>
	local resolvedResult = _ResolveDragSnapshot(manager, request)
	if not resolvedResult.success then
		return resolvedResult
	end

	local resolved = resolvedResult.value
	if resolved.MouseSnapshot.WorldPoint == nil then
		local errorType, message, data = Errors.BuildDragWorldPointNotFound(channelName)
		return Result.Err(errorType, message, data)
	end

	return Result.Ok(resolved)
end

local function _ResolveAnyDragSnapshot(
	manager: any,
	_channelName: string,
	request: TMouseDragRequest?
): Result.Result<TResolvedMouseDragResult>
	return _ResolveDragSnapshot(manager, request)
end

local function _GetResolveFn(
	mode: Types.TMouseDragMode
): (any, string, TMouseDragRequest?) -> Result.Result<TResolvedMouseDragResult>
	if mode == Enums.DragMode.Marquee then
		return _ResolveAnyDragSnapshot
	end

	return _ResolveWorldDragSnapshotOrErr
end

local function _ArePreviewTargetsEqual(
	left: { TMarqueeTargetEntry }?,
	right: { TMarqueeTargetEntry }?
): boolean
	if left == nil or right == nil then
		return left == right
	end

	if #left ~= #right then
		return false
	end

	for index, leftEntry in ipairs(left) do
		local rightEntry = right[index]
		if rightEntry == nil then
			return false
		end

		if leftEntry.Key ~= rightEntry.Key or leftEntry.ScreenPoint ~= rightEntry.ScreenPoint then
			return false
		end
	end

	return true
end

local function _ShouldFireMarqueePreviewChanged(
	previousSnapshot: TMouseDragSnapshot?,
	nextSnapshot: TMouseDragSnapshot
): boolean
	if previousSnapshot == nil then
		return true
	end

	local previousRect = previousSnapshot.NormalizedScreenRect
	local nextRect = nextSnapshot.NormalizedScreenRect
	local rectChanged = if previousRect == nil or nextRect == nil
		then previousRect ~= nextRect
		else previousRect.Min ~= nextRect.Min or previousRect.Max ~= nextRect.Max

	return rectChanged
		or previousSnapshot.PreviewMirrored ~= nextSnapshot.PreviewMirrored
		or not _ArePreviewTargetsEqual(previousSnapshot.PreviewTargets, nextSnapshot.PreviewTargets)
end

local function _ClearPreviewSelection(manager: any, channelName: string, request: TResolvedMouseDragRequest?)
	if manager._dragPreviewSelectionManager == nil or request == nil then
		return
	end

	manager._dragPreviewSelectionManager:Clear(_BuildPreviewSelectionChannelName(channelName, request))
end

local function _ApplyPreviewSelection(
	manager: any,
	channelName: string,
	request: TResolvedMouseDragRequest,
	previewTargets: { TMarqueeTargetEntry }?
): boolean
	local shouldMirror = request.MirrorPreviewSelection
	if not shouldMirror then
		_ClearPreviewSelection(manager, channelName, request)
		return false
	end

	if previewTargets == nil or #previewTargets == 0 then
		_ClearPreviewSelection(manager, channelName, request)
		return false
	end

	local selectionManager = _GetOrCreatePreviewSelectionManager(manager)
	local resolvedTargets = {}
	for _, entry in ipairs(previewTargets) do
		resolvedTargets[#resolvedTargets + 1] = entry.Target
	end

	selectionManager:SetSelectionSet(_BuildPreviewSelectionChannelName(channelName, request), {
		Targets = resolvedTargets,
		ResolverOptions = request.MarqueeSelectionOptions,
		Metadata = if request.MarqueeMetadata ~= nil then request.MarqueeMetadata else request.Metadata,
	})
	return true
end

local function _ResolveMarqueePreview(
	channelName: string,
	startSnapshot: TMouseSnapshot,
	currentSnapshot: TMouseSnapshot,
	request: TResolvedMouseDragRequest
): Result.Result<{ NormalizedScreenRect: Types.TScreenRect, PreviewTargets: { TMarqueeTargetEntry }, PreviewMirrored: boolean? }>
	return Marquee.ResolvePreview(channelName, startSnapshot, currentSnapshot, request):andThen(function(previewData)
		return Result.Ok({
			NormalizedScreenRect = previewData.NormalizedScreenRect,
			PreviewTargets = previewData.PreviewTargets,
		})
	end)
end

local function _CreateSessionSnapshot(
	manager: any,
	channelName: string,
	state: Types.TMouseDragState,
	endReason: Types.TMouseDragEndReason?,
	resolvedRequest: TResolvedMouseDragRequest,
	startSnapshot: TMouseSnapshot,
	currentSnapshot: TMouseSnapshot,
	endSnapshot: TMouseSnapshot?,
	metadata: { [string]: any }?
): Result.Result<TMouseDragSnapshot>
	if resolvedRequest.DragMode ~= Enums.DragMode.Marquee then
		return Result.Ok(_BuildDragSnapshot(
			channelName,
			resolvedRequest.DragMode,
			state,
			endReason,
			startSnapshot,
			currentSnapshot,
			endSnapshot,
			metadata,
			nil,
			nil,
			nil
		))
	end

	local previewResult = _ResolveMarqueePreview(channelName, startSnapshot, currentSnapshot, resolvedRequest)
	if not previewResult.success then
		return previewResult
	end

	local previewData = previewResult.value
	local previewMirrored = false
	if state == Enums.DragState.Active then
		previewMirrored = _ApplyPreviewSelection(manager, channelName, resolvedRequest, previewData.PreviewTargets)
	else
		_ClearPreviewSelection(manager, channelName, resolvedRequest)
	end

	return Result.Ok(_BuildDragSnapshot(
		channelName,
		resolvedRequest.DragMode,
		state,
		endReason,
		startSnapshot,
		currentSnapshot,
		endSnapshot,
		metadata,
		previewData.NormalizedScreenRect,
		previewData.PreviewTargets,
		previewMirrored
	))
end

local function _DestroySessionScope(manager: any, channelName: string)
	if manager._stash:HasScope(_BuildScopeKey(channelName)) then
		manager._stash:DestroyScope(_BuildScopeKey(channelName))
	end
end

function Drag.BeginDrag(manager: any, channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local transitionResult = Policies.CheckDragTransition(channelName, _GetSnapshot(manager, channelName), "Begin")
	if not transitionResult.success then
		return transitionResult
	end

	local requestResult = Policies.CheckDragRequest(request)
	if not requestResult.success then
		return requestResult
	end

	local resolvedRequest = Options.ResolveDragRequest(manager._config, request)
	local resolveFn = _GetResolveFn(resolvedRequest.DragMode)
	local resolvedResult = resolveFn(manager, channelName, request)
	if not resolvedResult.success then
		return resolvedResult
	end

	local scope = manager._stash:Scope(_BuildScopeKey(channelName))
	scope:AddCallback(DRAG_PREVIEW_SELECTION_KEY, function()
		_ClearPreviewSelection(manager, channelName, resolvedRequest)
	end, {
		Key = DRAG_PREVIEW_SELECTION_KEY,
		Label = DRAG_PREVIEW_SELECTION_KEY,
	})

	local resolved = resolvedResult.value
	local metadata = if resolvedRequest.MarqueeMetadata ~= nil then resolvedRequest.MarqueeMetadata else resolvedRequest.Metadata
	local dragSnapshotResult = _CreateSessionSnapshot(
		manager,
		channelName,
		Enums.DragState.Active,
		nil,
		resolvedRequest,
		resolved.MouseSnapshot,
		resolved.MouseSnapshot,
		nil,
		metadata
	)
	if not dragSnapshotResult.success then
		_DestroySessionScope(manager, channelName)
		return dragSnapshotResult
	end

	local dragSnapshot = dragSnapshotResult.value
	manager._dragStateByChannel[channelName] = {
		Request = resolvedRequest,
		Snapshot = dragSnapshot,
	}
	manager.DragStarted:Fire(channelName, dragSnapshot, nil)
	if dragSnapshot.Mode == Enums.DragMode.Marquee then
		manager.MarqueePreviewChanged:Fire(channelName, dragSnapshot, nil)
	end
	return Result.Ok(dragSnapshot)
end

function Drag.UpdateDrag(manager: any, channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local session = _GetSession(manager, channelName)
	local previousSnapshot = if session ~= nil then session.Snapshot else nil
	local transitionResult = Policies.CheckDragTransition(channelName, previousSnapshot, "Update")
	if not transitionResult.success then
		return transitionResult
	end

	local requestResult = Policies.CheckDragRequest(request)
	if not requestResult.success then
		return requestResult
	end

	local mode = session.Request.DragMode
	local requestToResolve = if request ~= nil then request else session.Request
	local resolveFn = _GetResolveFn(mode)
	local resolvedResult = resolveFn(manager, channelName, requestToResolve)
	if not resolvedResult.success then
		return resolvedResult
	end

	local resolved = resolvedResult.value
	local resolvedRequest = Options.ResolveDragRequest(manager._config, requestToResolve)
	local metadata = if resolvedRequest.MarqueeMetadata ~= nil
		then resolvedRequest.MarqueeMetadata
		else if resolvedRequest.Metadata ~= nil then resolvedRequest.Metadata else previousSnapshot.Metadata
	local dragSnapshotResult = _CreateSessionSnapshot(
		manager,
		channelName,
		Enums.DragState.Active,
		nil,
		resolvedRequest,
		previousSnapshot.StartSnapshot,
		resolved.MouseSnapshot,
		nil,
		metadata
	)
	if not dragSnapshotResult.success then
		return dragSnapshotResult
	end

	local dragSnapshot = dragSnapshotResult.value
	manager._dragStateByChannel[channelName] = {
		Request = resolvedRequest,
		Snapshot = dragSnapshot,
	}
	manager.DragUpdated:Fire(channelName, dragSnapshot, previousSnapshot)
	if dragSnapshot.Mode == Enums.DragMode.Marquee and _ShouldFireMarqueePreviewChanged(previousSnapshot, dragSnapshot) then
		manager.MarqueePreviewChanged:Fire(channelName, dragSnapshot, previousSnapshot)
	end
	return Result.Ok(dragSnapshot)
end

function Drag.EndDrag(manager: any, channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local session = _GetSession(manager, channelName)
	local previousSnapshot = if session ~= nil then session.Snapshot else nil
	local transitionResult = Policies.CheckDragTransition(channelName, previousSnapshot, "End")
	if not transitionResult.success then
		return transitionResult
	end

	local finalMouseSnapshot = previousSnapshot.CurrentSnapshot
	local resolvedRequest = session.Request
	local metadata = previousSnapshot.Metadata
	if request ~= nil then
		local requestResult = Policies.CheckDragRequest(request)
		if not requestResult.success then
			return requestResult
		end

		local resolveFn = _GetResolveFn(session.Request.DragMode)
		local resolvedResult = resolveFn(manager, channelName, request)
		if not resolvedResult.success then
			return resolvedResult
		end

		finalMouseSnapshot = resolvedResult.value.MouseSnapshot
		resolvedRequest = Options.ResolveDragRequest(manager._config, request)
		metadata = if resolvedRequest.MarqueeMetadata ~= nil
			then resolvedRequest.MarqueeMetadata
			else if resolvedRequest.Metadata ~= nil then resolvedRequest.Metadata else metadata
	end

	local dragSnapshotResult = _CreateSessionSnapshot(
		manager,
		channelName,
		Enums.DragState.Ended,
		Enums.DragEndReason.Completed,
		resolvedRequest,
		previousSnapshot.StartSnapshot,
		finalMouseSnapshot,
		finalMouseSnapshot,
		metadata
	)
	if not dragSnapshotResult.success then
		return dragSnapshotResult
	end

	local dragSnapshot = dragSnapshotResult.value
	manager._dragStateByChannel[channelName] = nil
	_DestroySessionScope(manager, channelName)

	manager.DragEnded:Fire(channelName, dragSnapshot, previousSnapshot)
	if dragSnapshot.Mode == Enums.DragMode.Marquee and _ShouldFireMarqueePreviewChanged(previousSnapshot, dragSnapshot) then
		manager.MarqueePreviewChanged:Fire(channelName, dragSnapshot, previousSnapshot)
	end
	return Result.Ok(dragSnapshot)
end

function Drag.CancelDrag(manager: any, channelName: string): Result.Result<TMouseDragSnapshot>
	local session = _GetSession(manager, channelName)
	local previousSnapshot = if session ~= nil then session.Snapshot else nil
	local transitionResult = Policies.CheckDragTransition(channelName, previousSnapshot, "Cancel")
	if not transitionResult.success then
		return transitionResult
	end

	local dragSnapshot = _BuildDragSnapshot(
		channelName,
		session.Request.DragMode,
		Enums.DragState.Cancelled,
		Enums.DragEndReason.Cancelled,
		previousSnapshot.StartSnapshot,
		previousSnapshot.CurrentSnapshot,
		nil,
		previousSnapshot.Metadata,
		previousSnapshot.NormalizedScreenRect,
		previousSnapshot.PreviewTargets,
		false
	)

	manager._dragStateByChannel[channelName] = nil
	_DestroySessionScope(manager, channelName)

	manager.DragCancelled:Fire(channelName, dragSnapshot, previousSnapshot)
	return Result.Ok(dragSnapshot)
end

return table.freeze(Drag)
