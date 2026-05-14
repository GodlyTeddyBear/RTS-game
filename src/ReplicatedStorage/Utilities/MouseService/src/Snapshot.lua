--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Orient = require(ReplicatedStorage.Utilities.Orient)

local Types = require(script.Parent.Types)

type TProjectionPlane = Types.TProjectionPlane
type TMouseSnapshot = Types.TMouseSnapshot
type TMouseSnapshotSource = Types.TMouseSnapshotSource

local Snapshot = {}

local function _ProjectWorldPoint(worldPoint: Vector3?, projectionPlane: TProjectionPlane?): Vector3?
	if worldPoint == nil or projectionPlane == nil then
		return nil
	end

	return Orient.ProjectPointToPlane(worldPoint, projectionPlane.Point, projectionPlane.Normal)
end

function Snapshot.Create(
	source: TMouseSnapshotSource,
	screenPoint: Vector2,
	camera: Camera,
	rayOrigin: Vector3,
	rayDirection: Vector3,
	rayLength: number,
	hit: RaycastResult?,
	worldPoint: Vector3?,
	projectionPlane: TProjectionPlane?,
	resolvedTarget: any
): TMouseSnapshot
	return table.freeze({
		Source = source,
		ScreenPoint = screenPoint,
		Camera = camera,
		RayOrigin = rayOrigin,
		RayDirection = rayDirection,
		RayLength = rayLength,
		Hit = hit,
		WorldPoint = worldPoint,
		ProjectedWorldPoint = _ProjectWorldPoint(worldPoint, projectionPlane),
		ResolvedTarget = resolvedTarget,
	})
end

return table.freeze(Snapshot)
