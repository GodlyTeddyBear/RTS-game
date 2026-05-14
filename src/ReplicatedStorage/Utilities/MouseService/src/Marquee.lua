--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local SelectionPlus = require(ReplicatedStorage.Utilities.SelectionPlus)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)

local Errors = require(script.Parent.Errors)
local Types = require(script.Parent.Types)

type TMarqueeTargetEntry = Types.TMarqueeTargetEntry
type TResolvedMouseDragRequest = Types.TResolvedMouseDragRequest
type TScreenRect = Types.TScreenRect

local MIN_RECT_SIZE = 2
local MIN_QUERY_SIZE = 8
local MIN_QUERY_HEIGHT = 32
local QUERY_PADDING = 8
local EPSILON = 1e-5

local Marquee = {}

local function _NormalizeScreenRect(startPoint: Vector2, currentPoint: Vector2): TScreenRect
	local minPoint = Vector2.new(math.min(startPoint.X, currentPoint.X), math.min(startPoint.Y, currentPoint.Y))
	local maxPoint = Vector2.new(math.max(startPoint.X, currentPoint.X), math.max(startPoint.Y, currentPoint.Y))
	local size = maxPoint - minPoint

	return table.freeze({
		Min = minPoint,
		Max = maxPoint,
		Center = minPoint + (size * 0.5),
		Size = size,
	})
end

local function _IsPointInRect(point: Vector2, rect: TScreenRect): boolean
	return point.X >= rect.Min.X
		and point.X <= rect.Max.X
		and point.Y >= rect.Min.Y
		and point.Y <= rect.Max.Y
end

local function _DoRectsOverlap(left: TScreenRect, right: TScreenRect): boolean
	return left.Min.X <= right.Max.X
		and left.Max.X >= right.Min.X
		and left.Min.Y <= right.Max.Y
		and left.Max.Y >= right.Min.Y
end

local function _IntersectRayWithPlane(
	rayOrigin: Vector3,
	rayDirection: Vector3,
	planePoint: Vector3,
	planeNormal: Vector3
): Vector3?
	local normal = planeNormal.Unit
	local denominator = rayDirection:Dot(normal)
	if math.abs(denominator) <= EPSILON then
		return nil
	end

	local distance = (planePoint - rayOrigin):Dot(normal) / denominator
	if distance < 0 then
		return nil
	end

	return rayOrigin + (rayDirection * distance)
end

local function _ProjectVectorToPlane(vector: Vector3, planeNormal: Vector3): Vector3?
	local normal = planeNormal.Unit
	local projected = vector - (normal * vector:Dot(normal))
	if projected.Magnitude <= EPSILON then
		return nil
	end

	return projected.Unit
end

local function _ResolveProjectionPlane(
	request: TResolvedMouseDragRequest,
	startSnapshot: Types.TMouseSnapshot,
	currentSnapshot: Types.TMouseSnapshot
): { Point: Vector3, Normal: Vector3 }?
	if request.ProjectionPlane ~= nil then
		return {
			Point = request.ProjectionPlane.Point,
			Normal = request.ProjectionPlane.Normal.Unit,
		}
	end

	local startPoint = if startSnapshot.ProjectedWorldPoint ~= nil
		then startSnapshot.ProjectedWorldPoint
		else startSnapshot.WorldPoint
	local currentPoint = if currentSnapshot.ProjectedWorldPoint ~= nil
		then currentSnapshot.ProjectedWorldPoint
		else currentSnapshot.WorldPoint

	if startPoint == nil and currentPoint == nil then
		return nil
	end

	local planePoint = if startPoint ~= nil and currentPoint ~= nil
		then startPoint:Lerp(currentPoint, 0.5)
		else if startPoint ~= nil then startPoint else currentPoint

	return {
		Point = planePoint :: Vector3,
		Normal = Vector3.yAxis,
	}
end

local function _ResolveCornerPoints(
	camera: Camera,
	screenRect: TScreenRect,
	planePoint: Vector3,
	planeNormal: Vector3
): { Vector3 }
	local corners = {
		Vector2.new(screenRect.Min.X, screenRect.Min.Y),
		Vector2.new(screenRect.Max.X, screenRect.Min.Y),
		Vector2.new(screenRect.Min.X, screenRect.Max.Y),
		Vector2.new(screenRect.Max.X, screenRect.Max.Y),
	}
	local resolvedCorners = {}

	for _, screenPoint in ipairs(corners) do
		local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y, 0)
		local worldPoint = _IntersectRayWithPlane(ray.Origin, ray.Direction, planePoint, planeNormal)
		if worldPoint ~= nil then
			resolvedCorners[#resolvedCorners + 1] = worldPoint
		end
	end

	return resolvedCorners
end

local function _BuildFallbackQueryBox(startPoint: Vector3, currentPoint: Vector3): (CFrame, Vector3)
	local center = startPoint:Lerp(currentPoint, 0.5)
	local delta = currentPoint - startPoint
	local size = Vector3.new(
		math.max(math.abs(delta.X) + QUERY_PADDING, MIN_QUERY_SIZE),
		MIN_QUERY_HEIGHT,
		math.max(math.abs(delta.Z) + QUERY_PADDING, MIN_QUERY_SIZE)
	)

	return CFrame.new(center), size
end

local function _ResolveQueryBox(
	startSnapshot: Types.TMouseSnapshot,
	currentSnapshot: Types.TMouseSnapshot,
	request: TResolvedMouseDragRequest
): (CFrame?, Vector3?)
	local anchorStart = if startSnapshot.ProjectedWorldPoint ~= nil then startSnapshot.ProjectedWorldPoint else startSnapshot.WorldPoint
	local anchorCurrent = if currentSnapshot.ProjectedWorldPoint ~= nil then currentSnapshot.ProjectedWorldPoint else currentSnapshot.WorldPoint
	if anchorStart == nil or anchorCurrent == nil then
		return nil, nil
	end

	local plane = _ResolveProjectionPlane(request, startSnapshot, currentSnapshot)
	if plane == nil then
		return _BuildFallbackQueryBox(anchorStart, anchorCurrent)
	end

	local screenRect = _NormalizeScreenRect(startSnapshot.ScreenPoint, currentSnapshot.ScreenPoint)
	local cornerPoints = _ResolveCornerPoints(startSnapshot.Camera, screenRect, plane.Point, plane.Normal)
	if #cornerPoints < 2 then
		return _BuildFallbackQueryBox(anchorStart, anchorCurrent)
	end

	local center = Vector3.zero
	for _, point in ipairs(cornerPoints) do
		center += point
	end
	center /= #cornerPoints

	local right = _ProjectVectorToPlane(startSnapshot.Camera.CFrame.RightVector, plane.Normal)
	if right == nil and #cornerPoints >= 2 then
		right = (cornerPoints[2] - cornerPoints[1]).Magnitude > EPSILON and (cornerPoints[2] - cornerPoints[1]).Unit or nil
	end
	if right == nil then
		return _BuildFallbackQueryBox(anchorStart, anchorCurrent)
	end

	local forward = _ProjectVectorToPlane(startSnapshot.Camera.CFrame.LookVector, plane.Normal)
	if forward == nil then
		forward = plane.Normal:Cross(right)
		if forward.Magnitude <= EPSILON then
			return _BuildFallbackQueryBox(anchorStart, anchorCurrent)
		end
		forward = forward.Unit
	end

	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, point in ipairs(cornerPoints) do
		local relative = point - center
		local x = relative:Dot(right)
		local z = relative:Dot(forward)
		minX = math.min(minX, x)
		maxX = math.max(maxX, x)
		minZ = math.min(minZ, z)
		maxZ = math.max(maxZ, z)
	end

	local sizeX = math.max(maxX - minX + QUERY_PADDING, MIN_QUERY_SIZE)
	local sizeZ = math.max(maxZ - minZ + QUERY_PADDING, MIN_QUERY_SIZE)
	local sizeY = math.max(request.RayLength * 0.1, MIN_QUERY_HEIGHT)

	return CFrame.lookAt(center, center + forward, plane.Normal), Vector3.new(sizeX, sizeY, sizeZ)
end

local function _ProjectScreenPoint(camera: Camera, worldPoint: Vector3): Vector2?
	local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPoint)
	if viewportPoint.Z <= 0 or not onScreen then
		return nil
	end

	return Vector2.new(viewportPoint.X, viewportPoint.Y)
end

local function _ResolveBoundsRect(camera: Camera, boundsCFrame: CFrame?, boundsSize: Vector3?): TScreenRect?
	if boundsCFrame == nil or boundsSize == nil then
		return nil
	end

	local halfSize = boundsSize * 0.5
	local corners = {
		Vector3.new(-halfSize.X, -halfSize.Y, -halfSize.Z),
		Vector3.new(-halfSize.X, -halfSize.Y, halfSize.Z),
		Vector3.new(-halfSize.X, halfSize.Y, -halfSize.Z),
		Vector3.new(-halfSize.X, halfSize.Y, halfSize.Z),
		Vector3.new(halfSize.X, -halfSize.Y, -halfSize.Z),
		Vector3.new(halfSize.X, -halfSize.Y, halfSize.Z),
		Vector3.new(halfSize.X, halfSize.Y, -halfSize.Z),
		Vector3.new(halfSize.X, halfSize.Y, halfSize.Z),
	}

	local projectedPoints = {}
	for _, localCorner in ipairs(corners) do
		local worldCorner = boundsCFrame:PointToWorldSpace(localCorner)
		local screenPoint = _ProjectScreenPoint(camera, worldCorner)
		if screenPoint ~= nil then
			projectedPoints[#projectedPoints + 1] = screenPoint
		end
	end

	if #projectedPoints == 0 then
		return nil
	end

	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	for _, point in ipairs(projectedPoints) do
		minX = math.min(minX, point.X)
		minY = math.min(minY, point.Y)
		maxX = math.max(maxX, point.X)
		maxY = math.max(maxY, point.Y)
	end

	return table.freeze({
		Min = Vector2.new(minX, minY),
		Max = Vector2.new(maxX, maxY),
		Center = Vector2.new((minX + maxX) * 0.5, (minY + maxY) * 0.5),
		Size = Vector2.new(maxX - minX, maxY - minY),
	})
end

local function _ResolveProjectedEntry(
	camera: Camera,
	target: SelectionPlus.TResolvedSelectionTarget
): (Vector2?, TScreenRect?)
	local screenPoint = _ProjectScreenPoint(camera, target.WorldPosition)
	local boundsRect = _ResolveBoundsRect(camera, target.BoundsCFrame, target.BoundsSize)
	return screenPoint, boundsRect
end

local function _ShouldIncludeTarget(
	screenRect: TScreenRect,
	screenPoint: Vector2?,
	boundsRect: TScreenRect?
): boolean
	if screenPoint ~= nil and _IsPointInRect(screenPoint, screenRect) then
		return true
	end

	if boundsRect ~= nil and _DoRectsOverlap(screenRect, boundsRect) then
		return true
	end

	return false
end

local function _SortEntries(entries: { TMarqueeTargetEntry })
	table.sort(entries, function(left, right)
		return left.Key:GetFullName() < right.Key:GetFullName()
	end)
end

function Marquee.ResolvePreview(
	channelName: string,
	startSnapshot: Types.TMouseSnapshot,
	currentSnapshot: Types.TMouseSnapshot,
	request: TResolvedMouseDragRequest
): Result.Result<{ NormalizedScreenRect: TScreenRect, PreviewTargets: { TMarqueeTargetEntry } }>
	local screenRect = _NormalizeScreenRect(startSnapshot.ScreenPoint, currentSnapshot.ScreenPoint)
	if screenRect.Size.X < MIN_RECT_SIZE and screenRect.Size.Y < MIN_RECT_SIZE then
		return Result.Ok({
			NormalizedScreenRect = screenRect,
			PreviewTargets = {},
		})
	end

	local queryCFrame, querySize = _ResolveQueryBox(startSnapshot, currentSnapshot, request)
	if queryCFrame == nil or querySize == nil then
		local errorType, message, data = Errors.BuildMarqueeCandidateQueryFailed(
			channelName,
			"Unable to derive a marquee query volume from the drag snapshots"
		)
		return Result.Err(errorType, message, data)
	end

	local candidateParts = SpatialQuery.OverlapBox(queryCFrame, querySize, request.MarqueeQueryOptions)
	local seenRoots = {}
	local previewTargets = {}
	for _, candidatePart in ipairs(candidateParts) do
		local resolvedTarget = SelectionPlus.ResolveTarget(candidatePart, request.MarqueeSelectionOptions)
		if resolvedTarget ~= nil and seenRoots[resolvedTarget.Root] ~= true then
			local screenPoint, boundsRect = _ResolveProjectedEntry(startSnapshot.Camera, resolvedTarget)
			if _ShouldIncludeTarget(screenRect, screenPoint, boundsRect) then
				seenRoots[resolvedTarget.Root] = true
				previewTargets[#previewTargets + 1] = table.freeze({
					Key = resolvedTarget.Root,
					Target = resolvedTarget,
					ScreenPoint = if screenPoint ~= nil then screenPoint else screenRect.Center,
					BoundsRect = boundsRect,
				})
			end
		end
	end

	_SortEntries(previewTargets)

	return Result.Ok({
		NormalizedScreenRect = screenRect,
		PreviewTargets = table.freeze(previewTargets),
	})
end

return table.freeze(Marquee)
