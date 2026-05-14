--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Enums = require(script.Parent.Enums)
local Errors = require(script.Parent.Errors)
local Options = require(script.Parent.Options)
local Policies = require(script.Parent.Policies)
local Types = require(script.Parent.Types)

type TMouseDragRequest = Types.TMouseDragRequest
type TMouseDragSnapshot = Types.TMouseDragSnapshot
type TResolvedMouseDragRequest = Types.TResolvedMouseDragRequest
type TMouseSnapshot = Types.TMouseSnapshot
type TResolvedMouseDragResult = {
	ResolvedRequest: TResolvedMouseDragRequest,
	MouseSnapshot: TMouseSnapshot,
}

local DRAG_SCOPE_PREFIX = "drag:"

local Drag = {}

local function _BuildScopeKey(channelName: string): string
	return DRAG_SCOPE_PREFIX .. channelName
end

local function _BuildDragSnapshot(
	channelName: string,
	state: Types.TMouseDragState,
	endReason: Types.TMouseDragEndReason?,
	startSnapshot: TMouseSnapshot,
	currentSnapshot: TMouseSnapshot,
	endSnapshot: TMouseSnapshot?,
	metadata: { [string]: any }?
): TMouseDragSnapshot
	local currentWorldPoint = currentSnapshot.WorldPoint :: Vector3
	local startWorldPoint = startSnapshot.WorldPoint :: Vector3
	local endWorldPoint = if endSnapshot ~= nil then endSnapshot.WorldPoint else nil

	return table.freeze({
		Channel = channelName,
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
		WorldDelta = currentWorldPoint - startWorldPoint,
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

local function _ResolveDragSnapshotOrErr(
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

function Drag.BeginDrag(manager: any, channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local transitionResult = Policies.CheckDragTransition(channelName, manager._dragStateByChannel[channelName], "Begin")
	if not transitionResult.success then
		return transitionResult
	end

	local resolvedResult = _ResolveDragSnapshotOrErr(manager, channelName, request)
	if not resolvedResult.success then
		return resolvedResult
	end

	local resolved = resolvedResult.value
	local dragSnapshot = _BuildDragSnapshot(
		channelName,
		Enums.DragState.Active,
		nil,
		resolved.MouseSnapshot,
		resolved.MouseSnapshot,
		nil,
		resolved.ResolvedRequest.Metadata
	)

	manager._stash:Scope(_BuildScopeKey(channelName))
	manager._dragStateByChannel[channelName] = dragSnapshot
	manager.DragStarted:Fire(channelName, dragSnapshot, nil)
	return Result.Ok(dragSnapshot)
end

function Drag.UpdateDrag(manager: any, channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local previousSnapshot = manager._dragStateByChannel[channelName]
	local transitionResult = Policies.CheckDragTransition(channelName, previousSnapshot, "Update")
	if not transitionResult.success then
		return transitionResult
	end

	local resolvedResult = _ResolveDragSnapshotOrErr(manager, channelName, request)
	if not resolvedResult.success then
		return resolvedResult
	end

	local resolved = resolvedResult.value
	local dragSnapshot = _BuildDragSnapshot(
		channelName,
		Enums.DragState.Active,
		nil,
		previousSnapshot.StartSnapshot,
		resolved.MouseSnapshot,
		nil,
		if resolved.ResolvedRequest.Metadata ~= nil then resolved.ResolvedRequest.Metadata else previousSnapshot.Metadata
	)

	manager._dragStateByChannel[channelName] = dragSnapshot
	manager.DragUpdated:Fire(channelName, dragSnapshot, previousSnapshot)
	return Result.Ok(dragSnapshot)
end

function Drag.EndDrag(manager: any, channelName: string, request: TMouseDragRequest?): Result.Result<TMouseDragSnapshot>
	local previousSnapshot = manager._dragStateByChannel[channelName]
	local transitionResult = Policies.CheckDragTransition(channelName, previousSnapshot, "End")
	if not transitionResult.success then
		return transitionResult
	end

	local finalMouseSnapshot = previousSnapshot.CurrentSnapshot
	local metadata = previousSnapshot.Metadata
	if request ~= nil then
		local resolvedResult = _ResolveDragSnapshotOrErr(manager, channelName, request)
		if not resolvedResult.success then
			return resolvedResult
		end

		finalMouseSnapshot = resolvedResult.value.MouseSnapshot
		metadata = if resolvedResult.value.ResolvedRequest.Metadata ~= nil
			then resolvedResult.value.ResolvedRequest.Metadata
			else metadata
	end

	local dragSnapshot = _BuildDragSnapshot(
		channelName,
		Enums.DragState.Ended,
		Enums.DragEndReason.Completed,
		previousSnapshot.StartSnapshot,
		finalMouseSnapshot,
		finalMouseSnapshot,
		metadata
	)

	manager._dragStateByChannel[channelName] = nil
	if manager._stash:HasScope(_BuildScopeKey(channelName)) then
		manager._stash:DestroyScope(_BuildScopeKey(channelName))
	end

	manager.DragEnded:Fire(channelName, dragSnapshot, previousSnapshot)
	return Result.Ok(dragSnapshot)
end

function Drag.CancelDrag(manager: any, channelName: string): Result.Result<TMouseDragSnapshot>
	local previousSnapshot = manager._dragStateByChannel[channelName]
	local transitionResult = Policies.CheckDragTransition(channelName, previousSnapshot, "Cancel")
	if not transitionResult.success then
		return transitionResult
	end

	local dragSnapshot = _BuildDragSnapshot(
		channelName,
		Enums.DragState.Cancelled,
		Enums.DragEndReason.Cancelled,
		previousSnapshot.StartSnapshot,
		previousSnapshot.CurrentSnapshot,
		nil,
		previousSnapshot.Metadata
	)

	manager._dragStateByChannel[channelName] = nil
	if manager._stash:HasScope(_BuildScopeKey(channelName)) then
		manager._stash:DestroyScope(_BuildScopeKey(channelName))
	end

	manager.DragCancelled:Fire(channelName, dragSnapshot, previousSnapshot)
	return Result.Ok(dragSnapshot)
end

return table.freeze(Drag)
