--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementFootprintResolver = require(ReplicatedStorage.Contexts.Placement.PlacementFootprintResolver)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local SpatialQuery = require(ReplicatedStorage.Utilities.SpatialQuery)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local PlacementGridRuntime = require(script.Parent.PlacementGridRuntime)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec
type TileDescriptor = WorldTypes.TileDescriptor
type FootprintCacheLookup = PlacementTypes.FootprintCacheLookup
type ResolvedFootprint = PlacementTypes.ResolvedFootprint

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

local function _GridCoordToWorldFromSpec(spec: GridSpec, row: number, col: number): Vector3
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (col - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (row - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
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

function PlacementCursorGridService.GetFootprintForAnchor(
	footprintCacheLookup: FootprintCacheLookup,
	structureType: string,
	anchorCoord: GridCoord,
	rotationQuarterTurns: number
): ResolvedFootprint?
	return PlacementFootprintResolver.Resolve(
		footprintCacheLookup,
		structureType,
		anchorCoord,
		rotationQuarterTurns
	)
end

function PlacementCursorGridService:ResolveGroundWorldPositionForFootprint(
	footprintCacheLookup: FootprintCacheLookup,
	anchorCoord: GridCoord,
	structureType: string,
	rotationQuarterTurns: number,
	placementCursorFolder: Instance?
): Vector3?
	local footprint = self.GetFootprintForAnchor(
		footprintCacheLookup,
		structureType,
		anchorCoord,
		rotationQuarterTurns
	)
	if footprint == nil then
		return nil
	end

	local gridSpec = self.GetGridSpec(anchorCoord.GridId)
	if gridSpec == nil then
		return nil
	end

	local centerRow = anchorCoord.Row + ((footprint.DepthTiles - 1) * 0.5)
	local centerCol = anchorCoord.Col + ((footprint.WidthTiles - 1) * 0.5)
	local tileCenter = _GridCoordToWorldFromSpec(gridSpec, centerRow, centerCol)
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

function PlacementCursorGridService.GetValidTiles(
	footprintCacheLookup: FootprintCacheLookup,
	structureType: string,
	occupiedSet: OccupiedSet,
	rotationQuarterTurns: number
): { GridCoord }
	local placementCost = PlacementConfig.STRUCTURE_PLACEMENT_COSTS[structureType]
	if placementCost == nil then
		return table.freeze({})
	end

	local footprintEntry = PlacementFootprintResolver.ResolveCacheEntry(
		footprintCacheLookup,
		structureType,
		rotationQuarterTurns
	)
	if footprintEntry == nil then
		error(("PlacementCursorGridService: missing footprint cache for '%s' rotation %d"):format(
			structureType,
			PlacementFootprintResolver.NormalizeRotationQuarterTurns(rotationQuarterTurns)
		))
	end

	local validTiles = {}
	local footprintWidthTiles = footprintEntry.WidthTiles
	local footprintDepthTiles = footprintEntry.DepthTiles
	local specialTileRequirementMode = footprintEntry.SpecialTileRequirementMode
	local requiresResourceTile = PlacementConfig.REQUIRES_RESOURCE_TILE[structureType] == true

	for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
		for row = 1, spec.GridRows do
			for col = 1, spec.GridCols do
				local coord = {
					GridId = spec.GridId,
					Row = row,
					Col = col,
				}
				local footprint = PlacementFootprintResolver.BuildOccupiedCoords(
					coord,
					footprintWidthTiles,
					footprintDepthTiles
				)
				local specialTileCount = 0
				local isValidAnchor = true

				for _, occupiedCoord in ipairs(footprint) do
					if occupiedCoord.Row < 1 or occupiedCoord.Row > spec.GridRows or occupiedCoord.Col < 1 or occupiedCoord.Col > spec.GridCols then
						isValidAnchor = false
						break
					end

					local descriptor = PlacementCursorGridService.GetTileDescriptor(occupiedCoord)
					local coordKey = _GetCoordKey(occupiedCoord)
					local zone = descriptor and descriptor.Zone or nil
					local isZoneDisallowed = zone ~= nil and PlacementConfig.BASE_DISALLOWED_ZONE_TYPES[zone] == true
					local isPlacementProhibited = descriptor ~= nil and descriptor.IsPlacementProhibited == true

					if descriptor == nil or isZoneDisallowed or isPlacementProhibited or occupiedSet[coordKey] == true then
						isValidAnchor = false
						break
					end

					if descriptor.Zone == "side_pocket" and descriptor.ResourceType ~= nil then
						specialTileCount += 1
					end
				end

				if requiresResourceTile then
					if specialTileRequirementMode == "AllTiles" then
						isValidAnchor = isValidAnchor and specialTileCount == #footprint
					else
						isValidAnchor = isValidAnchor and specialTileCount >= 1
					end
				end

				if isValidAnchor then
					table.insert(validTiles, _CloneCoord(coord))
				end
			end
		end
	end

	return table.freeze(validTiles)
end

return table.freeze(PlacementCursorGridService)
