--!strict

--[=[
    @class PlacementPlusFootprint
    Ground footprint helpers for deriving clearance sizes and support points.
    @server
    @client
]=]

local Types = require(script.Parent.Types)

-- ── Types ─────────────────────────────────────────────────────────────────────

type TPlacementFootprint = Types.TPlacementFootprint
type TPlacementSupportPointMode = Types.TPlacementSupportPointMode

-- ── Constants ─────────────────────────────────────────────────────────────────

-- Default support-point mode when a footprint does not specify one.
local DEFAULT_SUPPORT_POINT_MODE: TPlacementSupportPointMode = "CenterAndCorners"

local Footprint = {}

-- ── Private ───────────────────────────────────────────────────────────────────

-- Clones support points before freezing the footprint so callers cannot mutate shared arrays.
local function _CloneSupportPoints(points: { Vector3 }?): { Vector3 }?
	if points == nil then
		return nil
	end

	local clone = table.create(#points)
	for index, point in ipairs(points) do
		clone[index] = point
	end

	return table.freeze(clone)
end

-- Freezes nested support point arrays before freezing the footprint table itself.
local function _FreezeFootprint(footprint: TPlacementFootprint): TPlacementFootprint
	if footprint.SupportPoints ~= nil and not table.isfrozen(footprint.SupportPoints) then
		footprint.SupportPoints = table.freeze(footprint.SupportPoints)
	end

	return table.freeze(footprint)
end

-- Appends the four footprint corners using local-space offsets from the center.
local function _AppendCornerPoints(points: { Vector3 }, halfSize: Vector3)
	points[#points + 1] = Vector3.new(-halfSize.X, 0, -halfSize.Z)
	points[#points + 1] = Vector3.new(halfSize.X, 0, -halfSize.Z)
	points[#points + 1] = Vector3.new(-halfSize.X, 0, halfSize.Z)
	points[#points + 1] = Vector3.new(halfSize.X, 0, halfSize.Z)
end

-- ── Public ────────────────────────────────────────────────────────────────────

--[=[
    Builds a frozen ground footprint from a bounds size.
    @within PlacementPlusFootprint
    @param boundsSize Vector3 -- Bounds size used as the footprint size.
    @param padding Vector3? -- Optional clearance padding.
    @return TPlacementFootprint -- Frozen footprint data.
]=]
function Footprint.BuildFootprintFromBounds(boundsSize: Vector3, padding: Vector3?): TPlacementFootprint
	-- Footprints are frozen so profile helpers can reuse them without cloning on every call.
	return _FreezeFootprint({
		Size = boundsSize,
		Padding = padding,
		SupportPointMode = DEFAULT_SUPPORT_POINT_MODE,
		SupportPoints = nil,
	})
end

--[=[
    Builds local-space support points from a ground footprint.
    @within PlacementPlusFootprint
    @param footprint TPlacementFootprint -- Footprint data.
    @return { Vector3 } -- Frozen local-space support points.
]=]
function Footprint.BuildSupportPointsFromFootprint(footprint: TPlacementFootprint): { Vector3 }
	-- Preserve explicitly supplied points so callers can override the default pattern.
	if footprint.SupportPoints ~= nil then
		return _CloneSupportPoints(footprint.SupportPoints) :: { Vector3 }
	end

	local points = {}
	-- Fall back to the default center-plus-corners pattern when no custom points are supplied.
	local mode = footprint.SupportPointMode or DEFAULT_SUPPORT_POINT_MODE
	local halfSize = footprint.Size * 0.5

	if mode == "Center" or mode == "CenterAndCorners" then
		points[#points + 1] = Vector3.zero
	end

	if mode == "Corners" or mode == "CenterAndCorners" then
		_AppendCornerPoints(points, halfSize)
	end

	return table.freeze(points)
end

--[=[
    Builds a clearance size from footprint size and padding.
    @within PlacementPlusFootprint
    @param footprint TPlacementFootprint -- Footprint data.
    @return Vector3 -- Clearance size for overlap checks.
]=]
function Footprint.BuildClearanceSizeFromFootprint(footprint: TPlacementFootprint): Vector3
	if footprint.Padding == nil then
		return footprint.Size
	end

	return footprint.Size + footprint.Padding
end

return table.freeze(Footprint)
