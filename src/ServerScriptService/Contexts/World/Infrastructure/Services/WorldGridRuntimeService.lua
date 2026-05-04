--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type TileDescriptor = WorldTypes.TileDescriptor
type ZoneLayout = WorldTypes.ZoneLayout
type GridSpec = WorldTypes.GridSpec
type BoundsShape = {
	CFrame: CFrame,
	Size: Vector3,
	Center: Vector3,
}

local MISSING_PART_CODE = "MissingPlacementGridPart"
local INVALID_DIMENSIONS_CODE = "InvalidPlacementGridDimensions"
local MISSING_GRID_ID_CODE = "MissingPlacementGridId"
local DUPLICATE_GRID_ID_CODE = "DuplicatePlacementGridId"
local OVERLAPPING_GRIDS_CODE = "OverlappingPlacementGrids"

local WorldGridRuntimeService = {}
WorldGridRuntimeService.__index = WorldGridRuntimeService

function WorldGridRuntimeService.new()
	local self = setmetatable({}, WorldGridRuntimeService)
	self._cachedGridSpecsById = nil :: { [string]: GridSpec }?
	self._cachedGridSpecList = nil :: { GridSpec }?
	self._resourceParts = nil :: { BasePart }?
	self._resourceCoordKeySet = nil :: { [string]: boolean }?
	self._resourceTypeByKey = nil :: { [string]: string }?
	self._placementProhibitedParts = nil :: { BasePart }?
	self._blacklistNamedInstances = nil :: { Instance }?
	self._placementProhibitedCoordKeySet = nil :: { [string]: boolean }?
	self._mapContext = nil :: any
	return self
end

function WorldGridRuntimeService:Init(_registry: any, _name: string) end

function WorldGridRuntimeService:Start(registry: any, _name: string)
	self._mapContext = registry:Get("MapContext")
end

function WorldGridRuntimeService:_GetZoneContainer(zoneName: string): Instance?
	local mapContext = self._mapContext
	assert(mapContext ~= nil, "WorldGridRuntimeService: MapContext dependency is unavailable")

	local zoneResult = mapContext:GetZoneInstance(zoneName)
	assert(zoneResult.success, tostring(zoneResult.message or zoneResult.type or "MapContext zone lookup failed"))
	return zoneResult.value
end

function WorldGridRuntimeService:_GetGridParts(): { BasePart }
	local gridContainer = self:_GetZoneContainer("PlacementGrids")
	if gridContainer == nil then
		return {}
	end

	local gridParts = {}
	if gridContainer:IsA("BasePart") and gridContainer.Name == WorldConfig.GRID_PART_NAME then
		table.insert(gridParts, gridContainer)
	end

	for _, descendant in ipairs(gridContainer:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == WorldConfig.GRID_PART_NAME then
			table.insert(gridParts, descendant)
		end
	end

	return gridParts
end

function WorldGridRuntimeService:_GetResourceParts(): { BasePart }
	local parts = {}
	local resourcesContainer = self:_GetZoneContainer(WorldConfig.RESOURCE_ZONE_NAME)
	if resourcesContainer ~= nil then
		if resourcesContainer:IsA("BasePart") then
			table.insert(parts, resourcesContainer)
		else
			for _, instance in ipairs(resourcesContainer:GetDescendants()) do
				if instance:IsA("BasePart") then
					table.insert(parts, instance)
				end
			end
		end
	end

	return parts
end

function WorldGridRuntimeService:_GetPlacementProhibitedParts(): { BasePart }
	local parts = {}
	local prohibitedContainer = self:_GetZoneContainer("PlacementProhibited")
	if prohibitedContainer ~= nil then
		if prohibitedContainer:IsA("BasePart") then
			table.insert(parts, prohibitedContainer)
		else
			for _, instance in ipairs(prohibitedContainer:GetDescendants()) do
				if instance:IsA("BasePart") then
					table.insert(parts, instance)
				end
			end
		end
	end

	return parts
end

local function _GetGridId(gridPart: BasePart): string
	local gridId = gridPart:GetAttribute("GridId")
	assert(type(gridId) == "string" and #gridId > 0, MISSING_GRID_ID_CODE)
	return gridId
end

local function _BuildGridSpec(gridPart: BasePart): GridSpec
	local tileSize = WorldConfig.TILE_SIZE
	local authoredGridSize = gridPart.Size

	assert(tileSize > 0, INVALID_DIMENSIONS_CODE)
	assert(authoredGridSize.X > 0 and authoredGridSize.Z > 0, INVALID_DIMENSIONS_CODE)

	local gridCols = math.floor(authoredGridSize.X / tileSize)
	local gridRows = math.floor(authoredGridSize.Z / tileSize)
	assert(gridCols >= 1 and gridRows >= 1, INVALID_DIMENSIONS_CODE)
	local reconciledGridSize = Vector3.new(gridCols * tileSize, authoredGridSize.Y, gridRows * tileSize)

	local laneRow = math.ceil(gridRows / 2)
	local sidePocketRows = {}
	if laneRow - 1 >= 1 then
		table.insert(sidePocketRows, laneRow - 1)
	end
	if laneRow + 1 <= gridRows then
		table.insert(sidePocketRows, laneRow + 1)
	end

	return table.freeze({
		GridId = _GetGridId(gridPart),
		GridCFrame = gridPart.CFrame,
		GridSize = reconciledGridSize,
		TileSize = tileSize,
		GridRows = gridRows,
		GridCols = gridCols,
		LaneRow = laneRow,
		SidePocketRows = table.freeze(sidePocketRows),
	})
end

function WorldGridRuntimeService:GetValidationCodes(): {
	MissingPart: string,
	InvalidDimensions: string,
	MissingGridId: string,
	DuplicateGridId: string,
	OverlappingGrids: string,
}
	return table.freeze({
		MissingPart = MISSING_PART_CODE,
		InvalidDimensions = INVALID_DIMENSIONS_CODE,
		MissingGridId = MISSING_GRID_ID_CODE,
		DuplicateGridId = DUPLICATE_GRID_ID_CODE,
		OverlappingGrids = OVERLAPPING_GRIDS_CODE,
	})
end

function WorldGridRuntimeService:ResetCache()
	self._cachedGridSpecsById = nil
	self._cachedGridSpecList = nil
	self._resourceParts = nil
	self._resourceCoordKeySet = nil
	self._resourceTypeByKey = nil
	self._placementProhibitedParts = nil
	self._blacklistNamedInstances = nil
	self._placementProhibitedCoordKeySet = nil
end

function WorldGridRuntimeService:GetGridSpecs(): { [string]: GridSpec }
	if self._cachedGridSpecsById ~= nil then
		return self._cachedGridSpecsById
	end

	local gridParts = self:_GetGridParts()
	assert(#gridParts > 0, MISSING_PART_CODE)

	local specsById = {} :: { [string]: GridSpec }
	local specList = {} :: { GridSpec }

	for _, gridPart in ipairs(gridParts) do
		local spec = _BuildGridSpec(gridPart)
		assert(specsById[spec.GridId] == nil, DUPLICATE_GRID_ID_CODE)
		specsById[spec.GridId] = spec
		table.insert(specList, spec)
	end

	table.sort(specList, function(left: GridSpec, right: GridSpec): boolean
		return left.GridId < right.GridId
	end)

	self._cachedGridSpecsById = specsById
	self._cachedGridSpecList = specList
	return specsById
end

function WorldGridRuntimeService:GetGridSpecList(): { GridSpec }
	if self._cachedGridSpecList ~= nil then
		return self._cachedGridSpecList
	end

	self:GetGridSpecs()
	return self._cachedGridSpecList or {}
end

function WorldGridRuntimeService:GetGridSpec(gridId: string): GridSpec?
	return self:GetGridSpecs()[gridId]
end

function WorldGridRuntimeService:CoordToWorld(coord: GridCoord): Vector3
	local spec = self:GetGridSpec(coord.GridId)
	assert(spec ~= nil, "WorldGridRuntimeService: unknown GridId")
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (coord.Col - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (coord.Row - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

function WorldGridRuntimeService:WorldToCoord(worldPos: Vector3): GridCoord?
	for _, spec in ipairs(self:GetGridSpecList()) do
		local localPos = spec.GridCFrame:PointToObjectSpace(worldPos)
		local col = math.floor((localPos.X + spec.GridSize.X * 0.5) / spec.TileSize) + 1
		local row = math.floor((localPos.Z + spec.GridSize.Z * 0.5) / spec.TileSize) + 1

		if row >= 1 and row <= spec.GridRows and col >= 1 and col <= spec.GridCols then
			return table.freeze({
				GridId = spec.GridId,
				Row = row,
				Col = col,
			})
		end
	end

	return nil
end

local function _GetCoordKey(coord: GridCoord): string
	return `{coord.GridId}:{coord.Row}:{coord.Col}`
end

local function _GetPartResourceType(part: BasePart): string?
	if #part.Name > 0 then
		return part.Name
	end
	return nil
end

local function _NormalizeName(name: string): string
	return string.lower(name)
end

local function _GetBlacklistNameSet(): { [string]: boolean }
	local nameSet = {} :: { [string]: boolean }
	for _, name in ipairs(WorldConfig.PLACEMENT_BLACKLIST_NAMES) do
		if type(name) == "string" and #name > 0 then
			nameSet[_NormalizeName(name)] = true
		end
	end
	return nameSet
end

local function _IsInsidePartXZ(part: BasePart, worldPoint: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(worldPoint)
	local halfSize = part.Size * 0.5
	local epsilon = 1e-4
	return math.abs(localPoint.X) <= halfSize.X + epsilon and math.abs(localPoint.Z) <= halfSize.Z + epsilon
end

local function _TileOverlapsPartXZ(part: BasePart, worldCenter: Vector3, spec: GridSpec): boolean
	local halfTile = spec.TileSize * 0.5
	local right = spec.GridCFrame.RightVector
	local look = spec.GridCFrame.LookVector
	local sampleOffsets = {
		Vector3.zero,
		right * halfTile + look * halfTile,
		right * halfTile - look * halfTile,
		-right * halfTile + look * halfTile,
		-right * halfTile - look * halfTile,
	}

	for _, offset in ipairs(sampleOffsets) do
		if _IsInsidePartXZ(part, worldCenter + offset) then
			return true
		end
	end

	return false
end

function WorldGridRuntimeService:_GetResourcePartsCached(): { BasePart }
	if self._resourceParts ~= nil then
		return self._resourceParts
	end

	local parts = self:_GetResourceParts()
	self._resourceParts = parts
	return parts
end

function WorldGridRuntimeService:_GetPlacementProhibitedPartsCached(): { BasePart }
	if self._placementProhibitedParts ~= nil then
		return self._placementProhibitedParts
	end

	local parts = self:_GetPlacementProhibitedParts()
	self._placementProhibitedParts = parts
	return parts
end

function WorldGridRuntimeService:_GetRuntimeMapRoot(): Model?
	local mapContext = self._mapContext
	assert(mapContext ~= nil, "WorldGridRuntimeService: MapContext dependency is unavailable")

	local mapResult = mapContext:GetRuntimeMapInstance()
	assert(mapResult.success, tostring(mapResult.message or mapResult.type or "MapContext runtime map lookup failed"))
	return mapResult.value
end

function WorldGridRuntimeService:_GetBlacklistNamedInstances(): { Instance }
	if self._blacklistNamedInstances ~= nil then
		return self._blacklistNamedInstances
	end

	local runtimeMap = self:_GetRuntimeMapRoot()
	local nameSet = _GetBlacklistNameSet()
	local matches = {} :: { Instance }
	if runtimeMap ~= nil and next(nameSet) ~= nil then
		local function maybeInsert(candidate: Instance)
			local normalized = _NormalizeName(candidate.Name)
			if nameSet[normalized] ~= true then
				return
			end
			if candidate:IsA("BasePart") or candidate:IsA("Model") then
				table.insert(matches, candidate)
			end
		end

		maybeInsert(runtimeMap)
		for _, instance in ipairs(runtimeMap:GetDescendants()) do
			maybeInsert(instance)
		end
	end

	self._blacklistNamedInstances = matches
	return matches
end

local function _ResolveBoundsShape(instance: Instance): BoundsShape?
	if instance:IsA("BasePart") then
		return {
			CFrame = instance.CFrame,
			Size = instance.Size,
			Center = instance.Position,
		}
	end

	if instance:IsA("Model") then
		local ok, cframe, size = pcall(function()
			return instance:GetBoundingBox()
		end)
		if ok and typeof(cframe) == "CFrame" and typeof(size) == "Vector3" and size.X > 0 and size.Z > 0 then
			return {
				CFrame = cframe,
				Size = size,
				Center = cframe.Position,
			}
		end
	end

	return nil
end

local function _GetBoundsCorners(shape: BoundsShape): { Vector3 }
	local half = shape.Size * 0.5
	local corners = table.create(8)
	local index = 1
	for _, signX in ipairs({ -1, 1 }) do
		for _, signY in ipairs({ -1, 1 }) do
			for _, signZ in ipairs({ -1, 1 }) do
				corners[index] =
					shape.CFrame:PointToWorldSpace(Vector3.new(half.X * signX, half.Y * signY, half.Z * signZ))
				index += 1
			end
		end
	end
	return corners
end

local function _GetCoveredTileRange(spec: GridSpec, shape: BoundsShape): (number, number, number, number)
	local corners = _GetBoundsCorners(shape)
	local minLocalX = math.huge
	local maxLocalX = -math.huge
	local minLocalZ = math.huge
	local maxLocalZ = -math.huge

	for _, corner in ipairs(corners) do
		local localCorner = spec.GridCFrame:PointToObjectSpace(corner)
		minLocalX = math.min(minLocalX, localCorner.X)
		maxLocalX = math.max(maxLocalX, localCorner.X)
		minLocalZ = math.min(minLocalZ, localCorner.Z)
		maxLocalZ = math.max(maxLocalZ, localCorner.Z)
	end

	local gridMinX = -spec.GridSize.X * 0.5
	local gridMinZ = -spec.GridSize.Z * 0.5
	local tileSize = spec.TileSize
	local epsilon = 1e-6

	local minUnitsX = (minLocalX - gridMinX) / tileSize
	local maxUnitsX = (maxLocalX - gridMinX) / tileSize
	local minUnitsZ = (minLocalZ - gridMinZ) / tileSize
	local maxUnitsZ = (maxLocalZ - gridMinZ) / tileSize

	local minFloorX = math.floor(minUnitsX)
	local minFloorZ = math.floor(minUnitsZ)
	local colStart = minFloorX + 1
	local rowStart = minFloorZ + 1
	if math.abs(minUnitsX - minFloorX) <= epsilon then
		colStart = minFloorX
	end
	if math.abs(minUnitsZ - minFloorZ) <= epsilon then
		rowStart = minFloorZ
	end
	local colEnd = math.ceil(maxUnitsX)
	local rowEnd = math.ceil(maxUnitsZ)

	colStart = math.max(1, math.min(spec.GridCols, colStart))
	colEnd = math.max(1, math.min(spec.GridCols, colEnd))
	rowStart = math.max(1, math.min(spec.GridRows, rowStart))
	rowEnd = math.max(1, math.min(spec.GridRows, rowEnd))

	if colStart > colEnd or rowStart > rowEnd then
		return nil
	end

	return rowStart, rowEnd, colStart, colEnd
end

function WorldGridRuntimeService:_ResolveNearestEligibleCoord(worldPos: Vector3, spec: GridSpec): GridCoord?
	local bestCoord: GridCoord? = nil
	local bestDistanceSquared = math.huge

	for row = 1, spec.GridRows do
		if row ~= spec.LaneRow then
			for col = 1, spec.GridCols do
				local coord = {
					GridId = spec.GridId,
					Row = row,
					Col = col,
				}
				local tileCenter = self:CoordToWorld(coord)
				local delta = tileCenter - worldPos
				local distanceSquared = delta.X * delta.X + delta.Z * delta.Z
				if distanceSquared < bestDistanceSquared then
					bestDistanceSquared = distanceSquared
					bestCoord = coord
				end
			end
		end
	end

	return bestCoord
end

function WorldGridRuntimeService:_GetResolvedResourceTiles(): ({ [string]: boolean }, { [string]: string })
	if self._resourceCoordKeySet ~= nil and self._resourceTypeByKey ~= nil then
		return self._resourceCoordKeySet, self._resourceTypeByKey
	end

	local coordKeySet = {} :: { [string]: boolean }
	local resourceTypeByKey = {} :: { [string]: string }
	local resourceParts = self:_GetResourcePartsCached()
	for _, part in ipairs(resourceParts) do
		local partResourceType = _GetPartResourceType(part)
		if partResourceType == nil then
			continue
		end

		local matchedAnyTile = false
		for _, spec in ipairs(self:GetGridSpecList()) do
			for row = 1, spec.GridRows do
				if row ~= spec.LaneRow then
					for col = 1, spec.GridCols do
						local coord = {
							GridId = spec.GridId,
							Row = row,
							Col = col,
						}
						local tileCenter = self:CoordToWorld(coord)
						if _TileOverlapsPartXZ(part, tileCenter, spec) then
							local coordKey = _GetCoordKey(coord)
							if coordKeySet[coordKey] ~= true then
								coordKeySet[coordKey] = true
								resourceTypeByKey[coordKey] = partResourceType
							end
							matchedAnyTile = true
						end
					end
				end
			end
		end

		if not matchedAnyTile then
			local bestCoord = nil :: GridCoord?
			local bestDistanceSquared = math.huge
			for _, spec in ipairs(self:GetGridSpecList()) do
				local nearestCoord = self:_ResolveNearestEligibleCoord(part.Position, spec)
				if nearestCoord ~= nil then
					local tileCenter = self:CoordToWorld(nearestCoord)
					local delta = tileCenter - part.Position
					local distanceSquared = delta.X * delta.X + delta.Z * delta.Z
					if distanceSquared < bestDistanceSquared then
						bestDistanceSquared = distanceSquared
						bestCoord = nearestCoord
					end
				end
			end

			if bestCoord ~= nil then
				local coordKey = _GetCoordKey(bestCoord)
				if coordKeySet[coordKey] ~= true then
					coordKeySet[coordKey] = true
					resourceTypeByKey[coordKey] = partResourceType
				end
			end
		end
	end

	self._resourceCoordKeySet = coordKeySet
	self._resourceTypeByKey = resourceTypeByKey
	return coordKeySet, resourceTypeByKey
end

function WorldGridRuntimeService:_GetResolvedPlacementProhibitedTiles(): { [string]: boolean }
	if self._placementProhibitedCoordKeySet ~= nil then
		return self._placementProhibitedCoordKeySet
	end

	local coordKeySet = {} :: { [string]: boolean }
	local shapes = {} :: { BoundsShape }
	local seenInstances = {} :: { [Instance]: boolean }

	for _, part in ipairs(self:_GetPlacementProhibitedPartsCached()) do
		if seenInstances[part] ~= true then
			seenInstances[part] = true
			local shape = _ResolveBoundsShape(part)
			if shape ~= nil then
				table.insert(shapes, shape)
			end
		end
	end

	for _, instance in ipairs(self:_GetBlacklistNamedInstances()) do
		if seenInstances[instance] ~= true then
			seenInstances[instance] = true
			local shape = _ResolveBoundsShape(instance)
			if shape ~= nil then
				table.insert(shapes, shape)
			end
		end
	end

	for _, shape in ipairs(shapes) do
		local matchedAnyTile = false
		for _, spec in ipairs(self:GetGridSpecList()) do
			local rowStart, rowEnd, colStart, colEnd = _GetCoveredTileRange(spec, shape)
			if rowStart ~= nil and rowEnd ~= nil and colStart ~= nil and colEnd ~= nil then
				matchedAnyTile = true
				for row = rowStart, rowEnd do
					for col = colStart, colEnd do
						coordKeySet[("%s:%d:%d"):format(spec.GridId, row, col)] = true
					end
				end
			end
		end

		if not matchedAnyTile then
			local bestCoord = nil :: GridCoord?
			local bestDistanceSquared = math.huge
			for _, spec in ipairs(self:GetGridSpecList()) do
				local nearestCoord = self:_ResolveNearestEligibleCoord(shape.Center, spec)
				if nearestCoord ~= nil then
					local tileCenter = self:CoordToWorld(nearestCoord)
					local delta = tileCenter - shape.Center
					local distanceSquared = delta.X * delta.X + delta.Z * delta.Z
					if distanceSquared < bestDistanceSquared then
						bestDistanceSquared = distanceSquared
						bestCoord = nearestCoord
					end
				end
			end

			if bestCoord ~= nil then
				coordKeySet[_GetCoordKey(bestCoord)] = true
			end
		end
	end

	self._placementProhibitedCoordKeySet = coordKeySet
	return coordKeySet
end

function WorldGridRuntimeService:GetTileDescriptor(coord: GridCoord): TileDescriptor?
	local spec = self:GetGridSpec(coord.GridId)
	if spec == nil then
		return nil
	end
	if coord.Row < 1 or coord.Row > spec.GridRows or coord.Col < 1 or coord.Col > spec.GridCols then
		return nil
	end

	local zone = "buildable" :: WorldTypes.ZoneType
	local resourceType = nil :: string?
	if coord.Row == spec.LaneRow then
		zone = "lane"
	else
		local resourceCoordKeySet, resourceTypeByKey = self:_GetResolvedResourceTiles()
		local coordKey = _GetCoordKey(coord)
		if resourceCoordKeySet[coordKey] == true then
			zone = "side_pocket"
			resourceType = resourceTypeByKey[coordKey]
		end
	end

	local prohibitedCoordKeySet = self:_GetResolvedPlacementProhibitedTiles()

	return table.freeze({
		Zone = zone,
		ResourceType = resourceType,
		IsPlacementProhibited = prohibitedCoordKeySet[_GetCoordKey(coord)] == true,
	})
end

function WorldGridRuntimeService:BuildZoneLayout(spec: GridSpec): ZoneLayout
	local zoneLayout = table.create(spec.GridRows)

	for row = 1, spec.GridRows do
		local zoneRow = table.create(spec.GridCols)
		for col = 1, spec.GridCols do
			local descriptor = self:GetTileDescriptor({
				GridId = spec.GridId,
				Row = row,
				Col = col,
			})
			assert(descriptor ~= nil, "WorldContext: failed to build tile descriptor")
			zoneRow[col] = descriptor
		end
		zoneLayout[row] = table.freeze(zoneRow)
	end

	return table.freeze(zoneLayout)
end

return WorldGridRuntimeService
