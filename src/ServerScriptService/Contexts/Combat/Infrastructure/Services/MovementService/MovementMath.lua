--!strict

local MovementMath = {}

local function _ZigZagEncodeInt(value: number): number
	return if value >= 0 then value * 2 else -value * 2 - 1
end

function MovementMath.PackedSeparationCellKey(gx: number, gz: number): number
	local x = _ZigZagEncodeInt(gx)
	local z = _ZigZagEncodeInt(gz)
	local sum = x + z
	return sum * (sum + 1) / 2 + z
end

function MovementMath.FlowGoalKey(cell: Vector2): string
	return string.format("%d,%d", cell.X, cell.Y)
end

function MovementMath.ClampVector2Magnitude(vec: Vector2, maxMagnitude: number): Vector2
	if maxMagnitude <= 0 then
		return Vector2.zero
	end

	local magnitude = vec.Magnitude
	if magnitude > maxMagnitude then
		return vec * (maxMagnitude / magnitude)
	end

	return vec
end

function MovementMath.FlatXZ(worldPosition: Vector3): Vector2
	return Vector2.new(worldPosition.X, worldPosition.Z)
end

function MovementMath.XZDistance(a: Vector3, b: Vector3): number
	return (MovementMath.FlatXZ(a) - MovementMath.FlatXZ(b)).Magnitude
end

function MovementMath.ForEachCoveredSeparationCell(
	flatPosition: Vector2,
	radius: number,
	cellWidthStuds: number,
	callback: (number, number) -> ()
)
	if cellWidthStuds <= 0 then
		return
	end

	local offset = Vector2.new(radius, radius)
	local corner0X = math.round((flatPosition.X - offset.X) / cellWidthStuds)
	local corner0Z = math.round((flatPosition.Y - offset.Y) / cellWidthStuds)
	local corner1X = math.round((flatPosition.X + offset.X) / cellWidthStuds)
	local corner1Z = math.round((flatPosition.Y + offset.Y) / cellWidthStuds)
	local minGx = math.min(corner0X, corner1X)
	local maxGx = math.max(corner0X, corner1X)
	local minGz = math.min(corner0Z, corner1Z)
	local maxGz = math.max(corner0Z, corner1Z)

	for gx = minGx, maxGx do
		for gz = minGz, maxGz do
			callback(gx, gz)
		end
	end
end

return MovementMath
