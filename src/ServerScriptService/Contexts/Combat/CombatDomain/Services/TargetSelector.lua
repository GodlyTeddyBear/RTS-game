--!strict

--[=[
	@class TargetSelector
	Pure domain service for NPC target selection.

	Selects the nearest enemy from a list of candidates based on position.
	Provides distance-squared calculations for range checks without sqrt.

	Pattern: Domain layer — no side effects, no JECS world access.
	@server
]=]

local TargetSelector = {}
TargetSelector.__index = TargetSelector

export type TTargetSelector = typeof(setmetatable({}, TargetSelector))

function TargetSelector.new(): TTargetSelector
	local self = setmetatable({}, TargetSelector)
	return self
end

--[=[
	Select the nearest candidate entity from a given position.
	@within TargetSelector
	@param entityX number -- Source entity X position
	@param entityY number -- Source entity Y position
	@param entityZ number -- Source entity Z position
	@param candidates { { Entity: any, X: number, Y: number, Z: number } } -- List of candidate entities with positions
	@return any? -- The entity reference of the nearest candidate, or nil if empty
]=]
function TargetSelector:SelectNearest(
	entityX: number,
	entityY: number,
	entityZ: number,
	candidates: { { Entity: any, X: number, Y: number, Z: number } }
): any?
	if #candidates == 0 then
		return nil
	end

	local nearestEntity = nil
	local nearestDistSq = math.huge

	-- Find closest candidate using squared distance (avoids sqrt)
	for _, candidate in ipairs(candidates) do
		local dx = candidate.X - entityX
		local dy = candidate.Y - entityY
		local dz = candidate.Z - entityZ
		local distSq = dx * dx + dy * dy + dz * dz

		if distSq < nearestDistSq then
			nearestDistSq = distSq
			nearestEntity = candidate.Entity
		end
	end

	return nearestEntity
end

--[=[
	Calculate squared distance between two positions.

	Useful for range checks without the overhead of `math.sqrt`.
	@within TargetSelector
	@param x1 number
	@param y1 number
	@param z1 number
	@param x2 number
	@param y2 number
	@param z2 number
	@return number -- Squared distance (not square-rooted)
]=]
function TargetSelector:DistanceSquared(
	x1: number, y1: number, z1: number,
	x2: number, y2: number, z2: number
): number
	local dx = x2 - x1
	local dy = y2 - y1
	local dz = z2 - z1
	return dx * dx + dy * dy + dz * dz
end

return TargetSelector
