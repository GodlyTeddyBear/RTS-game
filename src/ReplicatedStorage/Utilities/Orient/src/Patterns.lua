--!strict

local Constants = require(script.Parent.Constants)
local Facing = require(script.Parent.Facing)
local Validation = require(script.Parent.Validation)

local TAU = Constants.TAU

local function _AngleStep(count: number): number
	-- Evenly partition a full turn across the requested count.
	return TAU / count
end

--[=[
    @class OrientPatterns
    Orbit, arc, formation, and offset generation helpers for `Orient`.

    This module turns a center point or transform into reusable point sets for
    circles, arcs, lines, columns, grids, spirals, and orbiting transforms.
    @server
    @client
]=]
local Patterns = {}

-- Circle and arc helpers
--[=[
    Returns a point on a circle in the XZ plane.
    @within OrientPatterns
    @param center Vector3 -- The circle center.
    @param radius number -- The circle radius.
    @param angleRadians number -- The angle around the circle.
    @return Vector3 -- The sampled point.
]=]
function Patterns.GetPointOnCircle(center: Vector3, radius: number, angleRadians: number): Vector3
	return Vector3.new(
		center.X + math.cos(angleRadians) * radius,
		center.Y,
		center.Z + math.sin(angleRadians) * radius
	)
end

function Patterns.GetPointOnFlatCircle(center: Vector3, radius: number, angleRadians: number): Vector3
	return Patterns.GetPointOnCircle(center, radius, angleRadians)
end

--[=[
    Returns evenly spaced points around a circle in the XZ plane.
    @within OrientPatterns
    @param center Vector3 -- The circle center.
    @param radius number -- The circle radius.
    @param count number -- The number of points to generate.
    @return { Vector3 } -- The sampled circle points.
]=]
function Patterns.GetPointsOnCircle(center: Vector3, radius: number, count: number): { Vector3 }
	Validation.AssertCount(count, "count")
	local points = table.create(count)
	local step = _AngleStep(count)
	for index = 1, count do
		points[index] = Patterns.GetPointOnCircle(center, radius, step * (index - 1))
	end
	return points
end

--[=[
    Returns evenly spaced points along an arc in the XZ plane.
    @within OrientPatterns
    @param center Vector3 -- The arc center.
    @param radius number -- The arc radius.
    @param startAngleRadians number -- The start angle.
    @param endAngleRadians number -- The end angle.
    @param count number -- The number of points to generate.
    @return { Vector3 } -- The sampled arc points.
]=]
function Patterns.GetPointsOnArc(
	center: Vector3,
	radius: number,
	startAngleRadians: number,
	endAngleRadians: number,
	count: number
): { Vector3 }
	Validation.AssertCount(count, "count")
	local points = table.create(count)
	if count == 1 then
		points[1] = Patterns.GetPointOnCircle(center, radius, startAngleRadians)
		return points
	end

	local step = (endAngleRadians - startAngleRadians) / (count - 1)
	for index = 1, count do
		points[index] = Patterns.GetPointOnCircle(center, radius, startAngleRadians + step * (index - 1))
	end
	return points
end

--[=[
    Returns a point in front of a transform by a distance.
    @within OrientPatterns
    @param cframe CFrame -- The reference transform.
    @param distance number -- The distance to move.
    @return Vector3 -- The sampled point.
]=]
function Patterns.GetPointInFront(cframe: CFrame, distance: number): Vector3
	return cframe.Position + cframe.LookVector * distance
end

--[=[
    Returns a point behind a transform by a distance.
    @within OrientPatterns
    @param cframe CFrame -- The reference transform.
    @param distance number -- The distance to move.
    @return Vector3 -- The sampled point.
]=]
function Patterns.GetPointBehind(cframe: CFrame, distance: number): Vector3
	return cframe.Position - cframe.LookVector * distance
end

--[=[
    Returns a point to the right of a transform by a distance.
    @within OrientPatterns
    @param cframe CFrame -- The reference transform.
    @param distance number -- The distance to move.
    @return Vector3 -- The sampled point.
]=]
function Patterns.GetPointRight(cframe: CFrame, distance: number): Vector3
	return cframe.Position + cframe.RightVector * distance
end

--[=[
    Returns a point to the left of a transform by a distance.
    @within OrientPatterns
    @param cframe CFrame -- The reference transform.
    @param distance number -- The distance to move.
    @return Vector3 -- The sampled point.
]=]
function Patterns.GetPointLeft(cframe: CFrame, distance: number): Vector3
	return cframe.Position - cframe.RightVector * distance
end

--[=[
    Returns a point above a transform by a distance.
    @within OrientPatterns
    @param cframe CFrame -- The reference transform.
    @param distance number -- The distance to move.
    @return Vector3 -- The sampled point.
]=]
function Patterns.GetPointAbove(cframe: CFrame, distance: number): Vector3
	return cframe.Position + cframe.UpVector * distance
end

--[=[
    Returns a point below a transform by a distance.
    @within OrientPatterns
    @param cframe CFrame -- The reference transform.
    @param distance number -- The distance to move.
    @return Vector3 -- The sampled point.
]=]
function Patterns.GetPointBelow(cframe: CFrame, distance: number): Vector3
	return cframe.Position - cframe.UpVector * distance
end

--[=[
    Converts a local offset into world space.
    @within OrientPatterns
    @param cframe CFrame -- The reference transform.
    @param localOffset Vector3 -- The local offset to convert.
    @return Vector3 -- The world-space point.
]=]
function Patterns.GetOffsetPoint(cframe: CFrame, localOffset: Vector3): Vector3
	return cframe:PointToWorldSpace(localOffset)
end

-- Radial and formation helpers
--[=[
    Returns radial offsets around the origin.
    @within OrientPatterns
    @param count number -- The number of offsets to generate.
    @param radius number -- The circle radius.
    @return { Vector3 } -- The radial offsets.
]=]
function Patterns.GetRadialOffsets(count: number, radius: number): { Vector3 }
	local offsets = table.create(count)
	local points = Patterns.GetPointsOnCircle(Vector3.zero, radius, count)
	for index = 1, count do
		offsets[index] = points[index]
	end
	return offsets
end

function Patterns.GetRingPositions(center: Vector3, count: number, radius: number): { Vector3 }
	return Patterns.GetPointsOnCircle(center, radius, count)
end

--[=[
    Returns a line of evenly spaced positions through a transform.
    @within OrientPatterns
    @param origin CFrame -- The local origin.
    @param count number -- The number of positions to generate.
    @param spacing number -- The spacing between positions.
    @return { Vector3 } -- The line positions.
]=]
function Patterns.GetFormationLine(origin: CFrame, count: number, spacing: number): { Vector3 }
	Validation.AssertCount(count, "count")
	local points = table.create(count)
	local half = (count - 1) * spacing * 0.5
	for index = 1, count do
		local localX = (index - 1) * spacing - half
		points[index] = origin:PointToWorldSpace(Vector3.new(localX, 0, 0))
	end
	return points
end

--[=[
    Returns a column of evenly spaced positions through a transform.
    @within OrientPatterns
    @param origin CFrame -- The local origin.
    @param count number -- The number of positions to generate.
    @param spacing number -- The spacing between positions.
    @return { Vector3 } -- The column positions.
]=]
function Patterns.GetFormationColumn(origin: CFrame, count: number, spacing: number): { Vector3 }
	Validation.AssertCount(count, "count")
	local points = table.create(count)
	local half = (count - 1) * spacing * 0.5
	for index = 1, count do
		local localZ = (index - 1) * spacing - half
		points[index] = origin:PointToWorldSpace(Vector3.new(0, 0, localZ))
	end
	return points
end

--[=[
    Returns a grid of evenly spaced positions through a transform.
    @within OrientPatterns
    @param origin CFrame -- The local origin.
    @param rows number -- The number of rows.
    @param columns number -- The number of columns.
    @param spacingX number -- The horizontal spacing.
    @param spacingZ number -- The depth spacing.
    @return { Vector3 } -- The grid positions.
]=]
function Patterns.GetFormationGrid(
	origin: CFrame,
	rows: number,
	columns: number,
	spacingX: number,
	spacingZ: number
): { Vector3 }
	Validation.AssertCount(rows, "rows")
	Validation.AssertCount(columns, "columns")
	local points = table.create(rows * columns)
	local halfWidth = (columns - 1) * spacingX * 0.5
	local halfDepth = (rows - 1) * spacingZ * 0.5
	local index = 1
	for row = 1, rows do
		for column = 1, columns do
			local localX = (column - 1) * spacingX - halfWidth
			local localZ = (row - 1) * spacingZ - halfDepth
			points[index] = origin:PointToWorldSpace(Vector3.new(localX, 0, localZ))
			index += 1
		end
	end
	return points
end

--[=[
    Returns a spiral of positions in the XZ plane.
    @within OrientPatterns
    @param center Vector3 -- The spiral center.
    @param count number -- The number of positions to generate.
    @param radiusStep number -- The radius increase per step.
    @param angleStepRadians number -- The angle increase per step.
    @return { Vector3 } -- The spiral positions.
]=]
function Patterns.GetSpiralPositions(
	center: Vector3,
	count: number,
	radiusStep: number,
	angleStepRadians: number
): { Vector3 }
	Validation.AssertCount(count, "count")
	local points = table.create(count)
	for index = 1, count do
		local radius = radiusStep * (index - 1)
		local angle = angleStepRadians * (index - 1)
		points[index] = Patterns.GetPointOnCircle(center, radius, angle)
	end
	return points
end

-- Orbit transforms
--[=[
    Returns an orbiting `CFrame` around a center point.
    @within OrientPatterns
    @param center Vector3 -- The orbit center.
    @param radius number -- The orbit radius.
    @param angleRadians number -- The angle around the orbit.
    @param lookAtCenter boolean -- Whether to face the center.
    @return CFrame -- The orbit transform.
]=]
function Patterns.GetOrbitCFrame(center: Vector3, radius: number, angleRadians: number, lookAtCenter: boolean): CFrame
	local position = Patterns.GetPointOnCircle(center, radius, angleRadians)
	if not lookAtCenter then
		return CFrame.new(position)
	end

	return Facing.BuildLookAt(position, center) or CFrame.new(position)
end

return table.freeze(Patterns)
