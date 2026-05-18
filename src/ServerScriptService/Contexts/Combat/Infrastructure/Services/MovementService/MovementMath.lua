--!strict
--!native
--!optimize 2

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

return table.freeze(MovementMath)
