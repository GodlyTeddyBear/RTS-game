--!strict

local Enums = require(script.Enums)
local Ground = require(script.Ground)
local Manager = require(script.Manager)
local Types = require(script.Types)

export type TProjectionPlane = Types.TProjectionPlane
export type TCameraProvider = Types.TCameraProvider
export type TMouseManagerConfig = Types.TMouseManagerConfig
export type TMouseRequest = Types.TMouseRequest
export type TResolvedMouseRequest = Types.TResolvedMouseRequest
export type TMouseSnapshot = Types.TMouseSnapshot
export type TMouseErrorData = Types.TMouseErrorData
export type TMouseSnapshotSource = Types.TMouseSnapshotSource
export type TMouseSelectionMode = Types.TMouseSelectionMode
export type TMouseHoverState = Types.TMouseHoverState
export type TMouseButton = Types.TMouseButton
export type TMouseGesturePhase = Types.TMouseGesturePhase
export type TMouseDragMode = Types.TMouseDragMode
export type TMouseDragState = Types.TMouseDragState
export type TMouseDragEndReason = Types.TMouseDragEndReason
export type TMouseSelectionRequest = Types.TMouseSelectionRequest
export type TResolvedMouseSelectionRequest = Types.TResolvedMouseSelectionRequest
export type TMouseSelectionSnapshot = Types.TMouseSelectionSnapshot
export type THoverRequest = Types.THoverRequest
export type TResolvedHoverRequest = Types.TResolvedHoverRequest
export type THoverSnapshot = Types.THoverSnapshot
export type TMouseGestureRequest = Types.TMouseGestureRequest
export type TResolvedMouseGestureRequest = Types.TResolvedMouseGestureRequest
export type TMouseGestureButtonState = Types.TMouseGestureButtonState
export type TMouseGestureSnapshot = Types.TMouseGestureSnapshot
export type TMouseGestureEvent = Types.TMouseGestureEvent
export type TScreenRect = Types.TScreenRect
export type TMarqueeTargetEntry = Types.TMarqueeTargetEntry
export type TMouseDragRequest = Types.TMouseDragRequest
export type TResolvedMouseDragRequest = Types.TResolvedMouseDragRequest
export type TMarqueeRequest = Types.TMarqueeRequest
export type TResolvedMarqueeRequest = Types.TResolvedMarqueeRequest
export type TMouseDragSnapshot = Types.TMouseDragSnapshot
export type TMouseManager = Types.TMouseManager

local MouseService = {
	SnapshotSource = Enums.SnapshotSource,
	SelectionMode = Enums.SelectionMode,
	HoverState = Enums.HoverState,
	MouseButton = Enums.MouseButton,
	GesturePhase = Enums.GesturePhase,
	DragMode = Enums.DragMode,
	DragState = Enums.DragState,
	DragEndReason = Enums.DragEndReason,
	ErrorKey = Enums.ErrorKey,
}

function MouseService.new(config: Types.TMouseManagerConfig?): Types.TMouseManager
	return Manager.new(config)
end

function MouseService.ResolveHitFromSnapshot(mouseSnapshot: Types.TMouseSnapshot): RaycastResult?
	if type(mouseSnapshot) ~= "table" then
		return nil
	end

	return mouseSnapshot.Hit
end

function MouseService.ResolveWorldPointFromSnapshot(mouseSnapshot: Types.TMouseSnapshot): Vector3?
	local hit = MouseService.ResolveHitFromSnapshot(mouseSnapshot)
	if hit == nil then
		return nil
	end

	return hit.Position
end

function MouseService.ResolveGroundPointFromSnapshot(
	mouseSnapshot: Types.TMouseSnapshot,
	baseExclude: { Instance }?
): Vector3?
	return Ground.ResolveGroundPointFromSnapshot(mouseSnapshot, baseExclude)
end

return table.freeze(MouseService)
