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
type AnchorValidationCache = {
	StaticVersion: number,
	AnchorKeysOrdered: { string },
	AnchorCoordByKey: { [string]: GridCoord },
	AnchorOccupiedCoordsByKey: { [string]: { GridCoord } },
	AnchorOccupiedCoordKeysByKey: { [string]: { string } },
	AffectedAnchorKeysByOccupiedKey: { [string]: { [string]: boolean } },
	LastOccupiedSet: OccupiedSet?,
	ValidAnchorKeySet: { [string]: boolean },
	ValidTiles: { GridCoord },
}

local PlacementCursorGridService = {}
local GROUND_FLAT_DOT = 1

local _cachedStaticVersion = -1
local _groundWorldPosByCoordKey = {} :: { [string]: Vector3 | boolean }
local _groundWorldPosByFootprintKey = {} :: { [string]: Vector3 | boolean }
local _anchorValidationCaches = {} :: { [string]: AnchorValidationCache }

local function _GetCoordKey(coord: GridCoord): string
	return (`{coord.GridId}:{coord.Row}:{coord.Col}`)
end

local function _GetValidationCacheKey(structureType: string, rotationQuarterTurns: number): string
	return (`{structureType}:{rotationQuarterTurns}`)
end

local function _GetFootprintGroundCacheKey(
	structureType: string,
	rotationQuarterTurns: number,
	anchorCoord: GridCoord
): string
	return (`{structureType}:{rotationQuarterTurns}:{anchorCoord.GridId}:{anchorCoord.Row}:{anchorCoord.Col}`)
end

local function _CloneCoord(coord: GridCoord): GridCoord
	return table.freeze({
		GridId = coord.GridId,
		Row = coord.Row,
		Col = coord.Col,
	})
end

local function _GridCoordToWorldFromSpec(spec: GridSpec, row: number, col: number): Vector3
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (col - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (row - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

local function _ClearStaticCaches()
	_groundWorldPosByCoordKey = {}
	_groundWorldPosByFootprintKey = {}
	_anchorValidationCaches = {}
end

local function _EnsureStaticCachesCurrent()
	local staticVersion = PlacementGridRuntime.GetStaticVersion()
	if _cachedStaticVersion == staticVersion then
		return
	end

	_cachedStaticVersion = staticVersion
	_ClearStaticCaches()
end

local function _CloneOccupiedSet(occupiedSet: OccupiedSet): OccupiedSet
	local clone = {}
	for key, value in occupiedSet do
		if value == true then
			clone[key] = true
		end
	end
	return clone
end

local function _CollectChangedOccupiedKeys(previous: OccupiedSet?, current: OccupiedSet): { [string]: boolean }
	local changedKeys = {}
	if previous == nil then
		for key, value in current do
			if value == true then
				changedKeys[key] = true
			end
		end
		return changedKeys
	end

	for key, value in previous do
		if value ~= (current[key] == true) then
			changedKeys[key] = true
		end
	end

	for key, value in current do
		if value ~= (previous[key] == true) then
			changedKeys[key] = true
		end
	end

	return changedKeys
end

local function _CreateAnchorValidationCache(
	footprintEntry: PlacementTypes.FootprintCacheEntry,
	structureType: string
): AnchorValidationCache
	local cache: AnchorValidationCache = {
		StaticVersion = _cachedStaticVersion,
		AnchorKeysOrdered = {},
		AnchorCoordByKey = {},
		AnchorOccupiedCoordsByKey = {},
		AnchorOccupiedCoordKeysByKey = {},
		AffectedAnchorKeysByOccupiedKey = {},
		LastOccupiedSet = nil,
		ValidAnchorKeySet = {},
		ValidTiles = table.freeze({}),
	}

	local requiresResourceTile = PlacementConfig.REQUIRES_RESOURCE_TILE[structureType] == true
	for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
		for row = 1, spec.GridRows do
			for col = 1, spec.GridCols do
				local anchorCoord = {
					GridId = spec.GridId,
					Row = row,
					Col = col,
				}
				local footprint = PlacementFootprintResolver.BuildOccupiedCoords(
					anchorCoord,
					footprintEntry.WidthTiles,
					footprintEntry.DepthTiles
				)
				local specialTileCount = 0
				local isStaticValid = true
				local occupiedCoordKeys = table.create(#footprint)

				for occupiedIndex, occupiedCoord in ipairs(footprint) do
					if occupiedCoord.Row < 1 or occupiedCoord.Row > spec.GridRows or occupiedCoord.Col < 1 or occupiedCoord.Col > spec.GridCols then
						isStaticValid = false
						break
					end

					local descriptor = PlacementGridRuntime.GetTileDescriptor(occupiedCoord)
					local coordKey = _GetCoordKey(occupiedCoord)
					occupiedCoordKeys[occupiedIndex] = coordKey

					local zone = descriptor and descriptor.Zone or nil
					local isZoneDisallowed = zone ~= nil and PlacementConfig.BASE_DISALLOWED_ZONE_TYPES[zone] == true
					local isPlacementProhibited = descriptor ~= nil and descriptor.IsPlacementProhibited == true

					if descriptor == nil or isZoneDisallowed or isPlacementProhibited then
						isStaticValid = false
						break
					end

					if descriptor.Zone == "side_pocket" and descriptor.ResourceType ~= nil then
						specialTileCount += 1
					end
				end

				if requiresResourceTile then
					if footprintEntry.SpecialTileRequirementMode == "AllTiles" then
						isStaticValid = isStaticValid and specialTileCount == #footprint
					else
						isStaticValid = isStaticValid and specialTileCount >= 1
					end
				end

				if not isStaticValid then
					continue
				end

				local anchorKey = _GetCoordKey(anchorCoord)
				local clonedAnchorCoord = _CloneCoord(anchorCoord)
				cache.AnchorKeysOrdered[#cache.AnchorKeysOrdered + 1] = anchorKey
				cache.AnchorCoordByKey[anchorKey] = clonedAnchorCoord
				cache.AnchorOccupiedCoordsByKey[anchorKey] = footprint
				cache.AnchorOccupiedCoordKeysByKey[anchorKey] = table.freeze(occupiedCoordKeys)

				for _, occupiedCoordKey in ipairs(occupiedCoordKeys) do
					local affectedAnchorKeys = cache.AffectedAnchorKeysByOccupiedKey[occupiedCoordKey]
					if affectedAnchorKeys == nil then
						affectedAnchorKeys = {}
						cache.AffectedAnchorKeysByOccupiedKey[occupiedCoordKey] = affectedAnchorKeys
					end
					affectedAnchorKeys[anchorKey] = true
				end
			end
		end
	end

	return cache
end

local function _IsAnchorAvailable(cache: AnchorValidationCache, anchorKey: string, occupiedSet: OccupiedSet): boolean
	local occupiedCoordKeys = cache.AnchorOccupiedCoordKeysByKey[anchorKey]
	if occupiedCoordKeys == nil then
		return false
	end

	for _, occupiedCoordKey in ipairs(occupiedCoordKeys) do
		if occupiedSet[occupiedCoordKey] == true then
			return false
		end
	end

	return true
end

local function _RebuildValidTiles(cache: AnchorValidationCache)
	local validTiles = {}
	for _, anchorKey in ipairs(cache.AnchorKeysOrdered) do
		if cache.ValidAnchorKeySet[anchorKey] == true then
			validTiles[#validTiles + 1] = cache.AnchorCoordByKey[anchorKey]
		end
	end

	cache.ValidTiles = table.freeze(validTiles)
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

function PlacementCursorGridService:_ResolveValidGroundHit(
	origin: Vector3,
	direction: Vector3,
	baseExclude: { Instance }?
): RaycastResult?
	local hit = self:_ResolveFirstNonGridHit(origin, direction, baseExclude)
	if hit == nil then
		return nil
	end

	local raycastConfig = PlacementConfig.GROUND_RAYCAST
	if raycastConfig.RequirePerfectlyFlat and hit.Normal:Dot(Vector3.yAxis) ~= GROUND_FLAT_DOT then
		return nil
	end

	return hit
end

function PlacementCursorGridService:ResolveGroundWorldPositionForCoord(
	coord: GridCoord,
	placementCursorFolder: Instance?
): Vector3?
	_EnsureStaticCachesCurrent()

	local coordKey = _GetCoordKey(coord)
	local cached = _groundWorldPosByCoordKey[coordKey]
	if cached ~= nil then
		return if cached == false then nil else cached
	end

	local tileCenter = PlacementGridRuntime.CoordToWorld(coord)
	local raycastConfig = PlacementConfig.GROUND_RAYCAST
	local rayOrigin = Vector3.new(tileCenter.X, tileCenter.Y + raycastConfig.HeightOffset, tileCenter.Z)
	local rayDirection = Vector3.new(0, -raycastConfig.Length, 0)
	local excludedInstances = self:GetCursorRaycastExcludeInstances(placementCursorFolder)

	local hit = self:_ResolveValidGroundHit(rayOrigin, rayDirection, excludedInstances)
	local resolved = if hit == nil then false else hit.Position
	_groundWorldPosByCoordKey[coordKey] = resolved

	return if resolved == false then nil else resolved
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
	_EnsureStaticCachesCurrent()

	local cacheKey = _GetFootprintGroundCacheKey(structureType, rotationQuarterTurns, anchorCoord)
	local cached = _groundWorldPosByFootprintKey[cacheKey]
	if cached ~= nil then
		return if cached == false then nil else cached
	end

	local footprint = self.GetFootprintForAnchor(
		footprintCacheLookup,
		structureType,
		anchorCoord,
		rotationQuarterTurns
	)
	if footprint == nil then
		_groundWorldPosByFootprintKey[cacheKey] = false
		return nil
	end

	local gridSpec = self.GetGridSpec(anchorCoord.GridId)
	if gridSpec == nil then
		_groundWorldPosByFootprintKey[cacheKey] = false
		return nil
	end

	local centerRow = anchorCoord.Row + ((footprint.DepthTiles - 1) * 0.5)
	local centerCol = anchorCoord.Col + ((footprint.WidthTiles - 1) * 0.5)
	local tileCenter = _GridCoordToWorldFromSpec(gridSpec, centerRow, centerCol)
	local raycastConfig = PlacementConfig.GROUND_RAYCAST
	local rayOrigin = Vector3.new(tileCenter.X, tileCenter.Y + raycastConfig.HeightOffset, tileCenter.Z)
	local rayDirection = Vector3.new(0, -raycastConfig.Length, 0)
	local excludedInstances = self:GetCursorRaycastExcludeInstances(placementCursorFolder)

	local hit = self:_ResolveValidGroundHit(rayOrigin, rayDirection, excludedInstances)
	local resolved = if hit == nil then false else hit.Position
	_groundWorldPosByFootprintKey[cacheKey] = resolved

	return if resolved == false then nil else resolved
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
	_EnsureStaticCachesCurrent()
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
	_EnsureStaticCachesCurrent()

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

	local validationCacheKey = _GetValidationCacheKey(structureType, footprintEntry.RotationQuarterTurns)
	local cache = _anchorValidationCaches[validationCacheKey]
	if cache == nil or cache.StaticVersion ~= _cachedStaticVersion then
		cache = _CreateAnchorValidationCache(footprintEntry, structureType)
		_anchorValidationCaches[validationCacheKey] = cache
	end

	local changedOccupiedKeys = _CollectChangedOccupiedKeys(cache.LastOccupiedSet, occupiedSet)
	local didChange = cache.LastOccupiedSet == nil
	for changedKey in changedOccupiedKeys do
		local affectedAnchorKeys = cache.AffectedAnchorKeysByOccupiedKey[changedKey]
		if affectedAnchorKeys == nil then
			continue
		end

		didChange = true
		for anchorKey in affectedAnchorKeys do
			cache.ValidAnchorKeySet[anchorKey] = _IsAnchorAvailable(cache, anchorKey, occupiedSet)
		end
	end

	if cache.LastOccupiedSet == nil then
		for _, anchorKey in ipairs(cache.AnchorKeysOrdered) do
			cache.ValidAnchorKeySet[anchorKey] = _IsAnchorAvailable(cache, anchorKey, occupiedSet)
		end
		didChange = true
	end

	cache.LastOccupiedSet = _CloneOccupiedSet(occupiedSet)

	if didChange then
		_RebuildValidTiles(cache)
	end

	return cache.ValidTiles
end

return table.freeze(PlacementCursorGridService)
