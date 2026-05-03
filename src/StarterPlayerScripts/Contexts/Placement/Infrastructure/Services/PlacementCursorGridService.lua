--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local PlacementGridRuntime = require(script.Parent.PlacementGridRuntime)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec
type TileDescriptor = WorldTypes.TileDescriptor

type OccupiedSet = { [string]: boolean }

local PlacementCursorGridService = {}

local function _GetCoordKey(coord: GridCoord): string
	return (`{coord.GridId}:{coord.Row}:{coord.Col}`)
end

local function _CloneCoord(coord: GridCoord): GridCoord
	return table.freeze({
		GridId = coord.GridId,
		Row = coord.Row,
		Col = coord.Col,
	})
end

function PlacementCursorGridService.CoordToWorld(coord: GridCoord): Vector3
	return PlacementGridRuntime.CoordToWorld(coord)
end

function PlacementCursorGridService.WorldToCoord(worldPos: Vector3): GridCoord?
	local coord = PlacementGridRuntime.WorldToCoord(worldPos)
	if coord == nil then
		return nil
	end
	return _CloneCoord(coord)
end

function PlacementCursorGridService:GetCursorRaycastExcludeInstances(placementCursorFolder: Instance?): { Instance }
	local excludedInstances = {}
	if placementCursorFolder ~= nil then
		table.insert(excludedInstances, placementCursorFolder)
	end

	return excludedInstances
end

function PlacementCursorGridService:_ResolveFirstNonGridHit(
	origin: Vector3,
	direction: Vector3,
	baseExclude: { Instance }?
): RaycastResult?
	local excludedInstances = {}
	if baseExclude ~= nil then
		for _, instance in ipairs(baseExclude) do
			table.insert(excludedInstances, instance)
		end
	end

	while true do
		local hit = SpatialQuery.Raycast(origin, direction, SpatialQuery.CreateRaycastOptions({
			FilterType = Enum.RaycastFilterType.Exclude,
			FilterDescendantsInstances = excludedInstances,
			RespectCanCollide = true,
		}))
		if hit == nil then
			return nil
		end

		if hit.Instance.Name ~= WorldConfig.GRID_PART_NAME then
			return hit
		end

		table.insert(excludedInstances, hit.Instance)
	end
end

function PlacementCursorGridService:ResolveGroundWorldPositionForCoord(
	coord: GridCoord,
	placementCursorFolder: Instance?
): Vector3?
	local tileCenter = PlacementGridRuntime.CoordToWorld(coord)
	local raycastConfig = PlacementConfig.GROUND_RAYCAST
	local rayOrigin = Vector3.new(tileCenter.X, tileCenter.Y + raycastConfig.HeightOffset, tileCenter.Z)
	local rayDirection = Vector3.new(0, -raycastConfig.Length, 0)
	local excludedInstances = self:GetCursorRaycastExcludeInstances(placementCursorFolder)

	local hit = self:_ResolveFirstNonGridHit(rayOrigin, rayDirection, excludedInstances)
	if hit == nil then
		return nil
	end

	return hit.Position
end

function PlacementCursorGridService.GetZone(coord: GridCoord): ZoneType?
	local descriptor = PlacementGridRuntime.GetTileDescriptor(coord)
	if descriptor == nil then
		return nil
	end
	return descriptor.Zone
end

function PlacementCursorGridService.GetTileDescriptor(coord: GridCoord): TileDescriptor?
	return PlacementGridRuntime.GetTileDescriptor(coord)
end

function PlacementCursorGridService.ResetRuntimeCache()
	PlacementGridRuntime.ResetCache()
end

function PlacementCursorGridService.GetGridSpecList(): { GridSpec }
	return PlacementGridRuntime.GetGridSpecList()
end

function PlacementCursorGridService.GetGridSpec(gridId: string): GridSpec?
	return PlacementGridRuntime.GetGridSpec(gridId)
end

function PlacementCursorGridService.GetValidTiles(structureType: string, occupiedSet: OccupiedSet): { GridCoord }
	local placementCost = PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType]
	if placementCost == nil then
		return table.freeze({})
	end

	local validTiles = {}
	for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
		for row = 1, spec.GridRows do
			for col = 1, spec.GridCols do
				local coord = {
					GridId = spec.GridId,
					Row = row,
					Col = col,
				}
				local descriptor = PlacementCursorGridService.GetTileDescriptor(coord)
				local coordKey = _GetCoordKey(coord)
				local zone = descriptor and descriptor.Zone or nil
				local isZoneDisallowed = zone ~= nil and PlacementConfig.BASE_DISALLOWED_ZONE_TYPES[zone] == true
				local isPlacementProhibited = descriptor ~= nil and descriptor.IsPlacementProhibited == true
				local requiresResourceTile = PlacementConfig.REQUIRES_RESOURCE_TILE[structureType] == true
				local hasRequiredResourceTile = not requiresResourceTile
					or (descriptor ~= nil and descriptor.Zone == "side_pocket" and descriptor.ResourceType ~= nil)

				if
					descriptor ~= nil
					and not isZoneDisallowed
					and not isPlacementProhibited
					and hasRequiredResourceTile
					and occupiedSet[coordKey] ~= true
				then
					table.insert(validTiles, _CloneCoord(coord))
				end
			end
		end
	end

	return table.freeze(validTiles)
end

return table.freeze(PlacementCursorGridService)
