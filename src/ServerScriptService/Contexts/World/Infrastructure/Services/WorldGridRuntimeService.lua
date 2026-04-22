--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type TileDescriptor = WorldTypes.TileDescriptor
type ZoneLayout = WorldTypes.ZoneLayout
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec

local MISSING_PART_CODE = "MissingPlacementGridPart"
local INVALID_DIMENSIONS_CODE = "InvalidPlacementGridDimensions"

--[=[
	@class WorldGridRuntimeService
	Computes and caches world-grid runtime geometry from the placement grid part.
	@server
]=]
local WorldGridRuntimeService = {}
WorldGridRuntimeService.__index = WorldGridRuntimeService

function WorldGridRuntimeService.new()
	local self = setmetatable({}, WorldGridRuntimeService)
	self._cachedGridSpec = nil :: GridSpec?
	self._sidePocketParts = nil :: { BasePart }?
	self._sidePocketCoordKeySet = nil :: { [string]: boolean }?
	self._sidePocketResourceByKey = nil :: { [string]: string }?
	return self
end

function WorldGridRuntimeService:Init(_registry: any, _name: string)
	-- No setup needed before first read.
end

local function _ResolvePath(path: string): Instance?
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end

	if #segments == 0 then
		return nil
	end

	local current: Instance = game
	local segmentIndex = 1
	local first = string.lower(segments[1])
	if first == "game" then
		segmentIndex = 2
	elseif first == "workspace" then
		current = Workspace
		segmentIndex = 2
	end

	for index = segmentIndex, #segments do
		local segment = segments[index]
		local child = current:FindFirstChild(segment)
		if child == nil then
			return nil
		end
		current = child
	end

	return current
end

local function _GetGridPart(): BasePart?
	local gridContainer = _ResolvePath(WorldConfig.GRID_FOLDER_PATH)
	if gridContainer == nil then
		return nil
	end

	if gridContainer:IsA("BasePart") and gridContainer.Name == WorldConfig.GRID_PART_NAME then
		return gridContainer
	end

	for _, descendant in ipairs(gridContainer:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == WorldConfig.GRID_PART_NAME then
			return descendant
		end
	end

	return nil
end

local function _GetSidePocketParts(): { BasePart }
	local parts = {}
	local sidePocketsContainer = _ResolvePath(WorldConfig.SIDE_POCKETS_PATH)
	if sidePocketsContainer ~= nil then
		if sidePocketsContainer:IsA("BasePart") then
			table.insert(parts, sidePocketsContainer)
		else
			for _, instance in ipairs(sidePocketsContainer:GetDescendants()) do
				if instance:IsA("BasePart") then
					table.insert(parts, instance)
				end
			end
		end
	end

	-- Fallback discovery to tolerate slight hierarchy drift in Studio.
	if #parts == 0 then
		local fallback = Workspace:FindFirstChild("SidePockets", true)
		if fallback ~= nil then
			if fallback:IsA("BasePart") then
				table.insert(parts, fallback)
			else
				for _, instance in ipairs(fallback:GetDescendants()) do
					if instance:IsA("BasePart") then
						table.insert(parts, instance)
					end
				end
			end
		end
	end

	return parts
end

local function _BuildGridSpec(gridPart: BasePart): GridSpec
	local tileSize = WorldConfig.TILE_SIZE
	local gridSize = gridPart.Size

	assert(tileSize > 0, INVALID_DIMENSIONS_CODE)
	assert(gridSize.X > 0 and gridSize.Z > 0, INVALID_DIMENSIONS_CODE)
	assert(math.abs(gridSize.X / tileSize - math.floor(gridSize.X / tileSize)) < 1e-6, INVALID_DIMENSIONS_CODE)
	assert(math.abs(gridSize.Z / tileSize - math.floor(gridSize.Z / tileSize)) < 1e-6, INVALID_DIMENSIONS_CODE)

	local gridCols = math.floor(gridSize.X / tileSize)
	local gridRows = math.floor(gridSize.Z / tileSize)
	assert(gridCols >= 1 and gridRows >= 1, INVALID_DIMENSIONS_CODE)

	local laneRow = math.ceil(gridRows / 2)
	local sidePocketRows = {}
	if laneRow - 1 >= 1 then
		table.insert(sidePocketRows, laneRow - 1)
	end
	if laneRow + 1 <= gridRows then
		table.insert(sidePocketRows, laneRow + 1)
	end

	return table.freeze({
		gridCFrame = gridPart.CFrame,
		gridSize = gridSize,
		tileSize = tileSize,
		gridRows = gridRows,
		gridCols = gridCols,
		laneRow = laneRow,
		sidePocketRows = table.freeze(sidePocketRows),
	})
end

function WorldGridRuntimeService:GetValidationCodes(): { MissingPart: string, InvalidDimensions: string }
	return table.freeze({
		MissingPart = MISSING_PART_CODE,
		InvalidDimensions = INVALID_DIMENSIONS_CODE,
	})
end

function WorldGridRuntimeService:ResetCache()
	self._cachedGridSpec = nil
	self._sidePocketParts = nil
	self._sidePocketCoordKeySet = nil
	self._sidePocketResourceByKey = nil
end

function WorldGridRuntimeService:GetGridSpec(): GridSpec
	if self._cachedGridSpec ~= nil then
		return self._cachedGridSpec
	end

	local gridPart = _GetGridPart()
	assert(gridPart ~= nil, MISSING_PART_CODE)

	local spec = _BuildGridSpec(gridPart)
	self._cachedGridSpec = spec
	return spec
end

function WorldGridRuntimeService:CoordToWorld(coord: GridCoord): Vector3
	local spec = self:GetGridSpec()
	local localX = -spec.gridSize.X * 0.5 + spec.tileSize * 0.5 + (coord.col - 1) * spec.tileSize
	local localZ = -spec.gridSize.Z * 0.5 + spec.tileSize * 0.5 + (coord.row - 1) * spec.tileSize
	return spec.gridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

function WorldGridRuntimeService:WorldToCoord(worldPos: Vector3): GridCoord?
	local spec = self:GetGridSpec()
	local localPos = spec.gridCFrame:PointToObjectSpace(worldPos)
	local col = math.floor((localPos.X + spec.gridSize.X * 0.5) / spec.tileSize) + 1
	local row = math.floor((localPos.Z + spec.gridSize.Z * 0.5) / spec.tileSize) + 1

	if row < 1 or row > spec.gridRows then
		return nil
	end
	if col < 1 or col > spec.gridCols then
		return nil
	end

	return table.freeze({
		row = row,
		col = col,
	})
end

local function _BuildResourceType(col: number): string
	return if (col / WorldConfig.SIDE_POCKET_COLUMN_INTERVAL) % 2 == 0 then "Crystal" else "Metal"
end

local function _GetCoordKey(row: number, col: number): string
	return (`{row}_{col}`)
end

local function _GetPartResourceType(part: BasePart): string?
	local attributeValue = part:GetAttribute("ResourceType")
	if type(attributeValue) == "string" and #attributeValue > 0 then
		return attributeValue
	end
	return nil
end

local function _IsInsidePartXZ(part: BasePart, worldPoint: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(worldPoint)
	local halfSize = part.Size * 0.5
	local epsilon = 1e-4
	return math.abs(localPoint.X) <= halfSize.X + epsilon and math.abs(localPoint.Z) <= halfSize.Z + epsilon
end

local function _TileOverlapsPartXZ(part: BasePart, worldCenter: Vector3, spec: GridSpec): boolean
	local halfTile = spec.tileSize * 0.5
	local right = spec.gridCFrame.RightVector
	local look = spec.gridCFrame.LookVector
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

function WorldGridRuntimeService:_GetSidePocketPartsCached(): { BasePart }
	if self._sidePocketParts ~= nil then
		return self._sidePocketParts
	end

	local parts = _GetSidePocketParts()
	self._sidePocketParts = parts
	return parts
end

function WorldGridRuntimeService:_ResolveSidePocketPart(worldPos: Vector3, spec: GridSpec): BasePart?
	local sidePocketParts = self:_GetSidePocketPartsCached()
	for _, part in ipairs(sidePocketParts) do
		if _TileOverlapsPartXZ(part, worldPos, spec) then
			return part
		end
	end
	return nil
end

function WorldGridRuntimeService:_ResolveNearestEligibleCoord(worldPos: Vector3, spec: GridSpec): GridCoord?
	local bestCoord: GridCoord? = nil
	local bestDistanceSquared = math.huge

	for row = 1, spec.gridRows do
		if row ~= spec.laneRow then
			for col = 1, spec.gridCols do
				local tileCenter = self:CoordToWorld({
					row = row,
					col = col,
				})
				local delta = tileCenter - worldPos
				local distanceSquared = delta.X * delta.X + delta.Z * delta.Z
				if distanceSquared < bestDistanceSquared then
					bestDistanceSquared = distanceSquared
					bestCoord = {
						row = row,
						col = col,
					}
				end
			end
		end
	end

	return bestCoord
end

function WorldGridRuntimeService:_GetResolvedSidePocketTiles(spec: GridSpec): ({ [string]: boolean }, { [string]: string })
	if self._sidePocketCoordKeySet ~= nil and self._sidePocketResourceByKey ~= nil then
		return self._sidePocketCoordKeySet, self._sidePocketResourceByKey
	end

	local coordKeySet = {} :: { [string]: boolean }
	local resourceByKey = {} :: { [string]: string }
	local sidePocketParts = self:_GetSidePocketPartsCached()

	for _, part in ipairs(sidePocketParts) do
		local matchedAnyTile = false
		local partResourceType = _GetPartResourceType(part)

		for row = 1, spec.gridRows do
			if row ~= spec.laneRow then
				for col = 1, spec.gridCols do
					local tileCenter = self:CoordToWorld({
						row = row,
						col = col,
					})

					if _TileOverlapsPartXZ(part, tileCenter, spec) then
						local coordKey = _GetCoordKey(row, col)
						coordKeySet[coordKey] = true
						if partResourceType ~= nil then
							resourceByKey[coordKey] = partResourceType
						end
						matchedAnyTile = true
					end
				end
			end
		end

		-- Reconcile marker parts that are near the grid but miss tile overlap.
		if not matchedAnyTile then
			local nearestCoord = self:_ResolveNearestEligibleCoord(part.Position, spec)
			if nearestCoord ~= nil then
				local coordKey = _GetCoordKey(nearestCoord.row, nearestCoord.col)
				coordKeySet[coordKey] = true
				if partResourceType ~= nil then
					resourceByKey[coordKey] = partResourceType
				end
			end
		end
	end

	self._sidePocketCoordKeySet = coordKeySet
	self._sidePocketResourceByKey = resourceByKey
	return coordKeySet, resourceByKey
end

function WorldGridRuntimeService:GetTileDescriptor(row: number, col: number): TileDescriptor?
	local spec = self:GetGridSpec()
	if row < 1 or row > spec.gridRows or col < 1 or col > spec.gridCols then
		return nil
	end

	local zone: ZoneType = "blocked"
	local resourceType: string? = nil
	if row == spec.laneRow then
		zone = "lane"
	else
		local coordKey = _GetCoordKey(row, col)
		local sidePocketCoordKeySet, sidePocketResourceByKey = self:_GetResolvedSidePocketTiles(spec)
		if sidePocketCoordKeySet[coordKey] == true then
			zone = "side_pocket"
			resourceType = sidePocketResourceByKey[coordKey] or _BuildResourceType(col)
		end
	end

	return table.freeze({
		zone = zone,
		resourceType = resourceType,
	})
end

function WorldGridRuntimeService:BuildZoneLayout(): ZoneLayout
	local spec = self:GetGridSpec()
	local zoneLayout = table.create(spec.gridRows)

	for row = 1, spec.gridRows do
		local zoneRow = table.create(spec.gridCols)
		for col = 1, spec.gridCols do
			local descriptor = self:GetTileDescriptor(row, col)
			assert(descriptor ~= nil, "WorldContext: failed to build tile descriptor")
			zoneRow[col] = descriptor
		end
		zoneLayout[row] = table.freeze(zoneRow)
	end

	return table.freeze(zoneLayout)
end

function WorldGridRuntimeService:GetLanePoints(): { spawnPoint: CFrame, goalPoint: CFrame }
	local spec = self:GetGridSpec()
	local laneRow = spec.laneRow
	local laneStart = self:CoordToWorld({ row = laneRow, col = 1 })
	local laneGoal = self:CoordToWorld({ row = laneRow, col = spec.gridCols })
	local rightVector = spec.gridCFrame.RightVector
	local yOffset = Vector3.new(0, WorldConfig.LANE_POINT_Y_OFFSET, 0)

	return table.freeze({
		spawnPoint = CFrame.new(laneStart - rightVector * spec.tileSize + yOffset),
		goalPoint = CFrame.new(laneGoal + rightVector * spec.tileSize + yOffset),
	})
end

return WorldGridRuntimeService
