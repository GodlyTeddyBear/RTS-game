--!strict
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local Snapshot = require(script.Parent.Snapshot)
local Types = require(script.Parent.Types)

type TResolvedMouseRequest = Types.TResolvedMouseRequest
type TMouseSnapshot = Types.TMouseSnapshot
type TMouseSnapshotSource = Types.TMouseSnapshotSource

type TResolvedRaycast = {
	RayOrigin: Vector3,
	RayDirection: Vector3,
	Hit: RaycastResult?,
}

local Resolver = {}

local function _ResolveQueryOptions(request: TResolvedMouseRequest): SpatialQuery.TQueryOptions?
	if #request.BaseExclude == 0 then
		return request.QueryOptions
	end

	local mergedExclude = table.clone(request.BaseExclude)
	local queryOptions = SpatialQuery.MergeOptions(nil, request.QueryOptions)
	local existingExclude = if queryOptions ~= nil then queryOptions.FilterDescendantsInstances else nil
	if existingExclude ~= nil then
		for _, instance in ipairs(existingExclude) do
			table.insert(mergedExclude, instance)
		end
	end

	return SpatialQuery.MergeOptions(queryOptions, {
		FilterType = Enum.RaycastFilterType.Exclude,
		FilterDescendantsInstances = mergedExclude,
	})
end

function Resolver.ResolveCamera(request: TResolvedMouseRequest): Camera?
	if request.CameraProvider ~= nil then
		return request.CameraProvider()
	end

	return Workspace.CurrentCamera
end

function Resolver.ResolveHit(
	screenPoint: Vector2,
	camera: Camera,
	request: TResolvedMouseRequest
): TResolvedRaycast
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y, 0)
	local queryOptions = _ResolveQueryOptions(request)
	local hit = SpatialQuery.Raycast(ray.Origin, ray.Direction * request.RayLength, queryOptions)

	return {
		RayOrigin = ray.Origin,
		RayDirection = ray.Direction,
		Hit = hit,
	}
end

function Resolver.ResolveHitFromScreenPoint(
	screenPoint: Vector2,
	camera: Camera,
	request: TResolvedMouseRequest
): TResolvedRaycast
	local ray = camera:ScreenPointToRay(screenPoint.X, screenPoint.Y, 0)
	local queryOptions = _ResolveQueryOptions(request)
	local hit = SpatialQuery.Raycast(ray.Origin, ray.Direction * request.RayLength, queryOptions)

	return {
		RayOrigin = ray.Origin,
		RayDirection = ray.Direction,
		Hit = hit,
	}
end

function Resolver.ResolveSnapshot(
	source: TMouseSnapshotSource,
	screenPoint: Vector2,
	camera: Camera,
	request: TResolvedMouseRequest
): TMouseSnapshot
	local resolvedRaycast = Resolver.ResolveHit(screenPoint, camera, request)
	local worldPoint = if resolvedRaycast.Hit ~= nil then resolvedRaycast.Hit.Position else nil
	local resolvedTarget = if request.ResolveTarget and resolvedRaycast.Hit ~= nil
		then SelectionPlus.ResolveTargetFromHit(resolvedRaycast.Hit, request.SelectionOptions)
		else nil

	return Snapshot.Create(
		source,
		screenPoint,
		camera,
		resolvedRaycast.RayOrigin,
		resolvedRaycast.RayDirection,
		request.RayLength,
		resolvedRaycast.Hit,
		worldPoint,
		request.ProjectionPlane,
		resolvedTarget
	)
end

return table.freeze(Resolver)
