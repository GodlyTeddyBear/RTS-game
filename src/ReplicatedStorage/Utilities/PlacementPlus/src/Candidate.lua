--!strict

--[=[
    @class PlacementPlusCandidate
    Candidate construction helpers for the shared `PlacementPlus` package.

    Flow: resolve input -> offset and snap position -> apply facing/alignment -> freeze.
    @server
    @client
]=]

local Orient = require(script.Parent.Parent.Parent.Orient)
local ModelPlus = require(script.Parent.Parent.Parent.ModelPlus)
local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Types = require(script.Parent.Types)

-- ── Types ─────────────────────────────────────────────────────────────────────

type TPlacementCandidate = Types.TPlacementCandidate
type TPlacementOptions = Types.TPlacementOptions

-- Default cursor ray length when callers omit one.
local DEFAULT_RAY_LENGTH = 1000

local Candidate = {}

-- ── Private ───────────────────────────────────────────────────────────────────

-- Copies metadata before freezing the candidate so callers cannot mutate shared option tables.
local function _CloneMetadata(metadata: { [string]: any }?): { [string]: any }?
	if metadata == nil then
		return nil
	end

	return table.freeze(table.clone(metadata))
end

-- Resolves rotation from either an explicit rotation CFrame or a full candidate CFrame.
local function _GetRotation(options: TPlacementOptions?): CFrame
	if options == nil then
		return CFrame.identity
	end

	if options.Rotation ~= nil then
		return Orient.GetRotation(options.Rotation)
	end

	if options.CFrame ~= nil then
		return Orient.GetRotation(options.CFrame)
	end

	return CFrame.identity
end

-- Builds the base transform from the resolved position while preserving any requested rotation.
local function _BuildBaseCFrame(position: Vector3, options: TPlacementOptions?): CFrame
	if options ~= nil and options.CFrame ~= nil then
		return Orient.WithPosition(options.CFrame, position)
	end

	return CFrame.new(position) * _GetRotation(options)
end

-- Resolves candidate bounds from explicit overrides or from the supplied model geometry.
local function _ResolveBounds(
	cframe: CFrame,
	options: TPlacementOptions?
): (CFrame?, Vector3?)
	if options == nil then
		return nil, nil
	end

	if options.BoundsCFrame ~= nil and options.BoundsSize ~= nil then
		return options.BoundsCFrame, options.BoundsSize
	end

	if options.Model ~= nil then
		local modelPivot = ModelPlus.GetPivot(options.Model)
		local modelBoundsCFrame, modelBoundsSize = ModelPlus.GetBounds(options.Model)
		local localBoundsCFrame = modelPivot:ToObjectSpace(modelBoundsCFrame)
		return cframe * localBoundsCFrame, modelBoundsSize
	end

	if options.BoundsSize ~= nil then
		return cframe, options.BoundsSize
	end

	return nil, nil
end

-- Freezes candidate tables before returning them to keep preview and validation payloads stable.
local function _FreezeCandidate(candidate: TPlacementCandidate): TPlacementCandidate
	if table.isfrozen(candidate) then
		return candidate
	end

	return table.freeze(candidate)
end

-- Pushes the candidate away from the supporting surface so it sits above the hit plane.
local function _ApplySurfaceOffset(position: Vector3, surfaceNormal: Vector3?, options: TPlacementOptions?): Vector3
	if options == nil or options.SurfaceOffset == nil or options.SurfaceOffset == 0 then
		return position
	end

	local normal = surfaceNormal or Vector3.yAxis
	return position + normal * options.SurfaceOffset
end

-- Shifts the candidate vertically so a model's bottom face rests on the target ground height.
local function _AlignToGround(candidate: TPlacementCandidate, options: TPlacementOptions?): TPlacementCandidate
	if options == nil or options.AlignToGround ~= true or options.Model == nil then
		return candidate
	end

	local boundsCFrame, boundsSize = _ResolveBounds(candidate.CFrame, options)
	if boundsCFrame == nil or boundsSize == nil then
		return candidate
	end

	local targetY = candidate.Position.Y
	local currentBottomY = boundsCFrame.Position.Y - (boundsSize.Y * 0.5)
	local yOffset = targetY - currentBottomY
	local alignedCFrame = Orient.TranslateWorld(candidate.CFrame, Vector3.new(0, yOffset, 0))

	return {
		CFrame = alignedCFrame,
		Position = alignedCFrame.Position,
		Hit = candidate.Hit,
		SurfaceNormal = candidate.SurfaceNormal,
		SurfaceInstance = candidate.SurfaceInstance,
		SurfaceMaterial = candidate.SurfaceMaterial,
		Model = candidate.Model,
		BoundsCFrame = nil,
		BoundsSize = nil,
		Metadata = candidate.Metadata,
	}
end

-- Applies facing overrides in priority order: target facing, raw yaw, then yaw snapping.
local function _ApplyFacing(candidate: TPlacementCandidate, options: TPlacementOptions?): TPlacementCandidate
	if options == nil then
		return candidate
	end

	local cframe = candidate.CFrame
	if options.FaceTarget ~= nil then
		local lookAtCFrame = Orient.BuildFlatLookAt(candidate.Position, options.FaceTarget)
		if lookAtCFrame ~= nil then
			cframe = lookAtCFrame
		end
	elseif options.YawRadians ~= nil then
		cframe = Orient.SetYaw(cframe, options.YawRadians)
	end

	if options.YawStepDegrees ~= nil then
		cframe = Orient.SnapYaw(cframe, options.YawStepDegrees)
	end

	return {
		CFrame = cframe,
		Position = cframe.Position,
		Hit = candidate.Hit,
		SurfaceNormal = candidate.SurfaceNormal,
		SurfaceInstance = candidate.SurfaceInstance,
		SurfaceMaterial = candidate.SurfaceMaterial,
		Model = candidate.Model,
		BoundsCFrame = candidate.BoundsCFrame,
		BoundsSize = candidate.BoundsSize,
		Metadata = candidate.Metadata,
	}
end

-- Builds the candidate payload from the resolved input position and optional raycast hit.
local function _BuildCandidate(
	position: Vector3,
	hit: RaycastResult?,
	options: TPlacementOptions?
): TPlacementCandidate
	-- Resolve surface metadata and apply the requested world-space offset.
	local surfaceNormal = if hit ~= nil then hit.Normal else nil
	local adjustedPosition = _ApplySurfaceOffset(position, surfaceNormal, options)

	-- Snap the adjusted position before building the base transform.
	if options ~= nil and options.PositionGridSize ~= nil then
		adjustedPosition = Orient.SnapPosition(adjustedPosition, options.PositionGridSize)
	end

	-- Build the candidate transform and copy any metadata that should survive freezing.
	local cframe = _BuildBaseCFrame(adjustedPosition, options)
	local candidate: TPlacementCandidate = {
		CFrame = cframe,
		Position = cframe.Position,
		Hit = hit,
		SurfaceNormal = surfaceNormal,
		SurfaceInstance = if hit ~= nil then hit.Instance else nil,
		SurfaceMaterial = if hit ~= nil then hit.Material else nil,
		Model = if options ~= nil then options.Model else nil,
		BoundsCFrame = nil,
		BoundsSize = nil,
		Metadata = if options ~= nil then _CloneMetadata(options.Metadata) else nil,
	}

	-- Apply facing and ground alignment before resolving bounds so validation sees the final pose.
	candidate = _ApplyFacing(candidate, options)
	candidate = _AlignToGround(candidate, options)

	-- Recompute bounds from the final transform and freeze the result for downstream callers.
	local boundsCFrame, boundsSize = _ResolveBounds(candidate.CFrame, options)
	candidate.BoundsCFrame = boundsCFrame
	candidate.BoundsSize = boundsSize
	candidate.Position = candidate.CFrame.Position

	return _FreezeCandidate(candidate)
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
    Casts from a camera screen position and builds a placement candidate from the first hit.
    @within PlacementPlusCandidate
    @param camera Camera -- Camera used to create the cursor ray.
    @param screenPosition Vector2 -- Viewport-space cursor position.
    @param rayLength number? -- Ray length in studs.
    @param queryOptions TQueryOptions? -- Spatial query filters.
    @param options TPlacementOptions? -- Candidate transform options.
    @return TPlacementCandidate? -- Candidate for the ray hit, or nil when nothing is hit.
]=]
function Candidate.BuildCandidateFromCursor(
	camera: Camera,
	screenPosition: Vector2,
	rayLength: number?,
	queryOptions: SpatialQuery.TQueryOptions?,
	options: TPlacementOptions?
): TPlacementCandidate?
	-- Resolve the requested ray length and bail out early when it is invalid.
	local resolvedRayLength = rayLength or DEFAULT_RAY_LENGTH
	if resolvedRayLength <= 0 then
		return nil
	end

	-- Cast a cursor ray from the screen position using the provided query filters.
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y, 0)
	local hit = SpatialQuery.Raycast(ray.Origin, ray.Direction * resolvedRayLength, queryOptions)
	if hit == nil then
		return nil
	end

	-- Reuse the hit-based builder so cursor and hit inputs share the same candidate path.
	return Candidate.BuildCandidateFromHit(hit, options)
end

--[=[
    Builds a placement candidate from an existing raycast hit.
    @within PlacementPlusCandidate
    @param hit RaycastResult -- Surface hit returned by Workspace raycasting.
    @param options TPlacementOptions? -- Candidate transform options.
    @return TPlacementCandidate -- Candidate with hit and surface metadata.
]=]
function Candidate.BuildCandidateFromHit(hit: RaycastResult, options: TPlacementOptions?): TPlacementCandidate
	return _BuildCandidate(hit.Position, hit, options)
end

--[=[
    Builds a placement candidate from a raw world position.
    @within PlacementPlusCandidate
    @param position Vector3 -- Candidate world position.
    @param options TPlacementOptions? -- Candidate transform options.
    @return TPlacementCandidate -- Candidate without raycast surface metadata.
]=]
function Candidate.BuildCandidateFromWorldPosition(
	position: Vector3,
	options: TPlacementOptions?
): TPlacementCandidate
	return _BuildCandidate(position, nil, options)
end

--[=[
    Returns the CFrame that should be used by preview visuals.
    @within PlacementPlusCandidate
    @param candidate TPlacementCandidate -- Candidate to preview.
    @return CFrame -- Candidate transform.
]=]
function Candidate.BuildPreviewCFrame(candidate: TPlacementCandidate): CFrame
	return candidate.CFrame
end

--[=[
    Snaps a world position to a scalar or per-axis grid.
    @within PlacementPlusCandidate
    @param position Vector3 -- Position to snap.
    @param gridSize TGridSize -- Snap grid size.
    @return Vector3 -- Snapped position.
]=]
function Candidate.SnapPosition(position: Vector3, gridSize: Orient.TGridSize): Vector3
	return Orient.SnapPosition(position, gridSize)
end

--[=[
    Rebuilds a candidate so its model bounds rest on the candidate ground height.
    @within PlacementPlusCandidate
    @param candidate TPlacementCandidate -- Candidate to align.
    @param options TPlacementOptions? -- Candidate transform options.
    @return TPlacementCandidate -- Aligned candidate, or the original candidate when alignment is disabled.
]=]
function Candidate.AlignToGround(candidate: TPlacementCandidate, options: TPlacementOptions?): TPlacementCandidate
	return _FreezeCandidate(_AlignToGround(candidate, options))
end

--[=[
    Applies yaw, facing target, and yaw snapping options to a candidate transform.
    @within PlacementPlusCandidate
    @param candidate TPlacementCandidate -- Candidate to rotate.
    @param options TPlacementOptions? -- Candidate transform options.
    @return TPlacementCandidate -- Rotated candidate.
]=]
function Candidate.ApplyFacing(candidate: TPlacementCandidate, options: TPlacementOptions?): TPlacementCandidate
	return _FreezeCandidate(_ApplyFacing(candidate, options))
end

return table.freeze(Candidate)
