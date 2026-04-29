--!strict

--[=[
    @class PlacementPlusRules
    Individual technical validation rules used by `PlacementPlus`.

    The package combines these rules into a frozen validation result for UI and game logic.
    @server
    @client
]=]

local SpatialQuery = require(script.Parent.Parent.Parent.SpatialQuery)
local Types = require(script.Parent.Types)

-- ── Types ─────────────────────────────────────────────────────────────────────

type TPlacementCandidate = Types.TPlacementCandidate
type TPlacementValidationOptions = Types.TPlacementValidationOptions

-- ── Constants ─────────────────────────────────────────────────────────────────

-- Default ray length when support validation does not provide an explicit distance.
local DEFAULT_SUPPORT_RAY_LENGTH = 6

-- Offset above each support point so the downward ray starts outside the candidate surface.
local SUPPORT_RAY_START_OFFSET = 0.1

local Rules = {}

--[=[
    @prop Reasons table
    @within PlacementPlusRules
    Frozen reason codes shared by the built-in placement validation rules.
]=]
Rules.Reasons = table.freeze({
	OutOfBounds = "OutOfBounds",
	InvalidSurface = "InvalidSurface",
	SlopeTooSteep = "SlopeTooSteep",
	Obstructed = "Obstructed",
	MissingSupport = "MissingSupport",
})

-- ── Private ───────────────────────────────────────────────────────────────────

-- Matches an instance or one of its descendants against the allowed-instance list.
local function _ContainsInstance(instances: { Instance }, target: Instance?): boolean
	if target == nil then
		return false
	end

	for _, instance in ipairs(instances) do
		if target == instance or target:IsDescendantOf(instance) then
			return true
		end
	end

	return false
end

-- Skips overlaps that come from the hit surface itself or from the candidate model.
local function _IsIgnoredOverlap(candidate: TPlacementCandidate, part: BasePart): boolean
	if candidate.SurfaceInstance ~= nil and (part == candidate.SurfaceInstance or part:IsDescendantOf(candidate.SurfaceInstance)) then
		return true
	end

	if candidate.Model ~= nil and part:IsDescendantOf(candidate.Model) then
		return true
	end

	return false
end

-- Resolves the clearance box size from explicit options or from the candidate bounds.
local function _ResolveClearanceSize(
	candidate: TPlacementCandidate,
	options: TPlacementValidationOptions
): Vector3?
	local size = options.ClearanceSize or candidate.BoundsSize
	if size == nil then
		return nil
	end

	local padding = options.ClearancePadding
	if padding == nil then
		return size
	end

	return size + padding
end

-- Converts local support points into world-space points for downward support raycasts.
local function _ResolveSupportPoints(candidate: TPlacementCandidate, options: TPlacementValidationOptions): { Vector3 }
	if options.SupportPoints ~= nil then
		local worldPoints = table.create(#options.SupportPoints)
		for index, localPoint in ipairs(options.SupportPoints) do
			worldPoints[index] = candidate.CFrame:PointToWorldSpace(localPoint)
		end
		return worldPoints
	end

	return { candidate.Position }
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
    Checks whether the candidate position is within optional world bounds.
    @within PlacementPlusRules
    @param candidate TPlacementCandidate -- Candidate to inspect.
    @param options TPlacementValidationOptions -- Validation options.
    @return boolean -- Whether the position is inside the configured bounds.
]=]
function Rules.IsWithinBounds(candidate: TPlacementCandidate, options: TPlacementValidationOptions): boolean
	local boundsMin = options.BoundsMin
	local boundsMax = options.BoundsMax
	if boundsMin == nil and boundsMax == nil then
		return true
	end

	local position = candidate.Position
	if boundsMin ~= nil and (position.X < boundsMin.X or position.Y < boundsMin.Y or position.Z < boundsMin.Z) then
		return false
	end

	if boundsMax ~= nil and (position.X > boundsMax.X or position.Y > boundsMax.Y or position.Z > boundsMax.Z) then
		return false
	end

	return true
end

--[=[
    Checks surface material, instance, and custom surface predicate restrictions.
    @within PlacementPlusRules
    @param candidate TPlacementCandidate -- Candidate to inspect.
    @param options TPlacementValidationOptions -- Validation options.
    @return boolean -- Whether the candidate surface is allowed.
]=]
function Rules.IsSurfaceAllowed(candidate: TPlacementCandidate, options: TPlacementValidationOptions): boolean
	-- Reject unsupported materials before consulting instance or custom predicates.
	if options.AllowedMaterials ~= nil then
		if candidate.SurfaceMaterial == nil or options.AllowedMaterials[candidate.SurfaceMaterial] ~= true then
			return false
		end
	end

	-- Instance and predicate checks refine the surface filter without short-circuiting earlier rules.
	if options.AllowedInstances ~= nil and not _ContainsInstance(options.AllowedInstances, candidate.SurfaceInstance) then
		return false
	end

	if options.SurfacePredicate ~= nil and not options.SurfacePredicate(candidate) then
		return false
	end

	return true
end

--[=[
    Checks whether the candidate surface normal stays under a maximum slope.
    @within PlacementPlusRules
    @param candidate TPlacementCandidate -- Candidate to inspect.
    @param options TPlacementValidationOptions -- Validation options.
    @return boolean -- Whether the candidate surface is within the slope limit.
]=]
function Rules.IsWithinSlopeLimit(candidate: TPlacementCandidate, options: TPlacementValidationOptions): boolean
	if options.MaxSlopeDegrees == nil or candidate.SurfaceNormal == nil then
		return true
	end

	if candidate.SurfaceNormal.Magnitude <= 0 then
		return false
	end

	local normal = candidate.SurfaceNormal.Unit
	local dot = math.clamp(normal:Dot(Vector3.yAxis), -1, 1)
	local slopeDegrees = math.deg(math.acos(dot))
	return slopeDegrees <= options.MaxSlopeDegrees
end

--[=[
    Checks whether the candidate footprint is clear of overlapping parts.
    @within PlacementPlusRules
    @param candidate TPlacementCandidate -- Candidate to inspect.
    @param options TPlacementValidationOptions -- Validation options.
    @return boolean -- Whether the clearance box is unobstructed.
]=]
function Rules.IsClearOfObstacles(candidate: TPlacementCandidate, options: TPlacementValidationOptions): boolean
	if options.RequireClearance ~= true and options.ClearanceSize == nil then
		return true
	end

	-- Build the overlap box from the candidate's final bounds so clearance matches the preview pose.
	local clearanceSize = _ResolveClearanceSize(candidate, options)
	if clearanceSize == nil then
		return true
	end

	-- Ignore the supporting surface and candidate model so the clearance check only catches foreign parts.
	local clearanceCFrame = candidate.BoundsCFrame or candidate.CFrame
	local overlappingParts = SpatialQuery.OverlapBox(clearanceCFrame, clearanceSize, options.ClearanceQueryOptions)
	for _, part in ipairs(overlappingParts) do
		if not _IsIgnoredOverlap(candidate, part) then
			return false
		end
	end

	return true
end

--[=[
    Checks whether every configured support point has a downward raycast hit.
    @within PlacementPlusRules
    @param candidate TPlacementCandidate -- Candidate to inspect.
    @param options TPlacementValidationOptions -- Validation options.
    @return boolean -- Whether required support exists.
]=]
function Rules.HasRequiredSupport(candidate: TPlacementCandidate, options: TPlacementValidationOptions): boolean
	if options.RequireSupport ~= true then
		return true
	end

	-- Support rays default to a short downward check unless the caller overrides the distance.
	local rayLength = options.SupportRayLength or options.SupportDistance or DEFAULT_SUPPORT_RAY_LENGTH
	if rayLength <= 0 then
		return false
	end

	-- Check each support point independently so a single missing contact invalidates the placement.
	for _, point in ipairs(_ResolveSupportPoints(candidate, options)) do
		local origin = point + Vector3.yAxis * SUPPORT_RAY_START_OFFSET
		local hit = SpatialQuery.Raycast(origin, -Vector3.yAxis * rayLength, options.SupportQueryOptions)
		if hit == nil then
			return false
		end
	end

	return true
end

return table.freeze(Rules)
