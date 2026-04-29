--!strict

local Constants = require(script.Parent.Constants)
local Facing = require(script.Parent.Facing)
local Validation = require(script.Parent.Validation)

local TAU = Constants.TAU

local function _AngleStep(count: number): number
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

function Patterns.GetPointsOnCircle(center: Vector3, radius: number, count: number): { Vector3 }
	Validation.AssertCount(count, "count")
	local points = table.create(count)
	local step = _AngleStep(count)
	for index = 1, count do
		points[index] = Patterns.GetPointOnCircle(center, radius, step * (index - 1))
	end
	return points
end

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

function Patterns.GetPointInFront(cframe: CFrame, distance: number): Vector3
	return cframe.Position + cframe.LookVector * distance
end

function Patterns.GetPointBehind(cframe: CFrame, distance: number): Vector3
	return cframe.Position - cframe.LookVector * distance
end

function Patterns.GetPointRight(cframe: CFrame, distance: number): Vector3
	return cframe.Position + cframe.RightVector * distance
end

function Patterns.GetPointLeft(cframe: CFrame, distance: number): Vector3
	return cframe.Position - cframe.RightVector * distance
end

function Patterns.GetPointAbove(cframe: CFrame, distance: number): Vector3
	return cframe.Position + cframe.UpVector * distance
end

function Patterns.GetPointBelow(cframe: CFrame, distance: number): Vector3
	return cframe.Position - cframe.UpVector * distance
end

function Patterns.GetOffsetPoint(cframe: CFrame, localOffset: Vector3): Vector3
	return cframe:PointToWorldSpace(localOffset)
end

-- Radial and formation helpers
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
function Patterns.GetOrbitCFrame(center: Vector3, radius: number, angleRadians: number, lookAtCenter: boolean): CFrame
	local position = Patterns.GetPointOnCircle(center, radius, angleRadians)
	if not lookAtCenter then
		return CFrame.new(position)
	end

	return Facing.BuildLookAt(position, center) or CFrame.new(position)
end

return table.freeze(Patterns)
