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

function Resolver.ResolveSnapshot(
	source: TMouseSnapshotSource,
	screenPoint: Vector2,
	camera: Camera,
	request: TResolvedMouseRequest
): TMouseSnapshot
	-- Build the world ray from the resolved screen point
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y, 0)
	local queryOptions = _ResolveQueryOptions(request)

	-- Query the world once for the current mouse ray
	local hit = SpatialQuery.Raycast(ray.Origin, ray.Direction * request.RayLength, queryOptions)
	local worldPoint = if hit ~= nil then hit.Position else nil
	local resolvedTarget = if request.ResolveTarget and hit ~= nil
		then SelectionPlus.ResolveTargetFromHit(hit, request.SelectionOptions)
		else nil

	-- Freeze the normalized snapshot payload
	return Snapshot.Create(
		source,
		screenPoint,
		camera,
		ray.Origin,
		ray.Direction,
		request.RayLength,
		hit,
		worldPoint,
		request.ProjectionPlane,
		resolvedTarget
	)
end

return table.freeze(Resolver)
