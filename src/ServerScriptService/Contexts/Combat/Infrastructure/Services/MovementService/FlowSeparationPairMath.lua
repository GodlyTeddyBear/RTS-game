--!strict

local FlowSeparationPairMath = {}

function FlowSeparationPairMath.ComputePairDelta(
	ax: number,
	ay: number,
	bx: number,
	by: number,
	radiusA: number,
	radiusB: number,
	kForce: number,
	minSeparationDistance: number
): (number, number, boolean)
	local dx = ax - bx
	local dy = ay - by
	local distance = math.sqrt(dx * dx + dy * dy)
	local penetration = radiusA + radiusB - distance
	if penetration <= 0 or distance <= minSeparationDistance then
		return 0, 0, false
	end

	local force = kForce * penetration * penetration / distance
	return dx * force, dy * force, true
end

return table.freeze(FlowSeparationPairMath)
