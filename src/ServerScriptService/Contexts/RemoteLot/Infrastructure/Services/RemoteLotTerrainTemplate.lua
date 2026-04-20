--!strict

--[=[
	@class RemoteLotTerrainTemplate
	Manages terrain template stamping and clearing for remote lots.
	@server
]=]

--[[
	Reads terrain voxels from workspace.TerrainHelper.TemplateBounds once at
	server startup and caches them in memory.

	StampTerrain writes cached voxels at a destination.
	ClearTerrain removes terrain in the same destination footprint.

	Why this implementation matters:
	- Terrain:WriteVoxels requires:
	  1) destination Region3 is grid-aligned to the voxel resolution
	  2) destination voxel dimensions exactly match materials/occupancy array shape
	- materials/occupancy are captured from _templateRegion in Init().
	- Destination placement must preserve both grid phase and region size.

	Failure modes this avoids:
	- Rebuilding region from world-snapped center +/- half can break grid phase.
	- Expanding destination with ExpandToGrid can change dimensions and mismatch arrays.

	Correct approach:
	- Snap movement delta relative to _templateCenter in 4-stud steps.
	- Translate original template min/max by that snapped delta.
	- This keeps destination aligned and same-sized as cached voxel arrays.
]]

local RemoteLotTerrainTemplate = {}
RemoteLotTerrainTemplate.__index = RemoteLotTerrainTemplate

export type TRemoteLotTerrainTemplate = typeof(setmetatable(
	{} :: {
		_materials: { any },
		_occupancy: { any },
		_templateRegion: Region3,
		_templateCenter: Vector3,
	},
	RemoteLotTerrainTemplate
))

function RemoteLotTerrainTemplate.new(): TRemoteLotTerrainTemplate
	local self = setmetatable({}, RemoteLotTerrainTemplate)
	self._materials = nil :: any
	self._occupancy = nil :: any
	self._templateRegion = nil :: any
	self._templateCenter = nil :: any
	return self
end

function RemoteLotTerrainTemplate:Init(_registry: any, _name: string)
	local boundsPart = workspace.TerrainHelper.TemplateBounds :: BasePart
	assert(boundsPart, "[RemoteLotTerrainTemplate] workspace.TerrainHelper.TemplateBounds not found")

	-- Step 1: Compute region from bounds part and expand to voxel grid (4-stud resolution)
	local half = boundsPart.Size / 2
	local region = Region3.new(
		boundsPart.Position - half,
		boundsPart.Position + half
	):ExpandToGrid(4)

	self._templateRegion = region
	self._templateCenter = region.CFrame.Position

	-- Step 2: Cache terrain voxels from the template region
	local materials, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	self._materials = materials
	self._occupancy = occupancy
end

--[=[
	Returns the center position of the template region used for voxel reads.
	This center is the reference point for all snapped destination placement.
	@within RemoteLotTerrainTemplate
	@return Vector3
]=]
function RemoteLotTerrainTemplate:GetTemplateCenter(): Vector3
	return self._templateCenter
end

--[=[
	Returns a valid destination center for model placement that matches terrain
	stamping phase and resolution.
	@within RemoteLotTerrainTemplate
	@param position Vector3
	@return Vector3 -- Snapped position aligned to 4-stud grid
]=]
function RemoteLotTerrainTemplate:GetSnappedPosition(position: Vector3): Vector3
	return self:_SnapDeltaFromTemplateCenter(position) + self._templateCenter
end

-- Snaps only the movement delta (relative to template center) to 4-stud voxel resolution.
-- Relative snapping preserves the template's grid phase.
function RemoteLotTerrainTemplate:_SnapDeltaFromTemplateCenter(position: Vector3): Vector3
	local r = 4
	local delta = position - self._templateCenter
	return Vector3.new(
		math.round(delta.X / r) * r,
		math.round(delta.Y / r) * r,
		math.round(delta.Z / r) * r
	)
end

-- Builds destination region by translating the template region bounds.
-- This preserves exact voxel dimensions required by WriteVoxels.
function RemoteLotTerrainTemplate:_GetDestinationRegion(destination: Vector3): Region3
	local half = self._templateRegion.Size / 2
	local templateMin = self._templateCenter - half
	local templateMax = self._templateCenter + half
	local delta = self:_SnapDeltaFromTemplateCenter(destination)
	return Region3.new(templateMin + delta, templateMax + delta)
end

--[=[
	Writes the terrain template into the world centered at the given destination.
	@within RemoteLotTerrainTemplate
	@param destination Vector3
]=]
function RemoteLotTerrainTemplate:StampTerrain(destination: Vector3)
	local destRegion = self:_GetDestinationRegion(destination)
	-- Write cached voxels to the destination region with 4-stud resolution
	workspace.Terrain:WriteVoxels(destRegion, 4, self._materials, self._occupancy)
end

--[=[
	Clears terrain in the same footprint used for stamping.
	@within RemoteLotTerrainTemplate
	@param destination Vector3
]=]
function RemoteLotTerrainTemplate:ClearTerrain(destination: Vector3)
	local destRegion = self:_GetDestinationRegion(destination)
	-- Fill the entire destination region with air to clear terrain
	workspace.Terrain:FillBlock(
		CFrame.new(destRegion.CFrame.Position),
		destRegion.Size,
		Enum.Material.Air
	)
end

return RemoteLotTerrainTemplate
