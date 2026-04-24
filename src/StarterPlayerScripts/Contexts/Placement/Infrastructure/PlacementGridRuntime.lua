--!strict

--[[
    Module: PlacementGridRuntime
    Purpose: Resolves client-side world grid geometry and tile descriptors for placement and cursor helpers.
    Used In System: Called by placement services to convert between world positions, grid coordinates, and valid tile zones.
    Boundaries: Owns client-side resolution and caching only; does not own authoritative world state or placement decisions.
]]

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type TileDescriptor = WorldTypes.TileDescriptor
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec

--[=[
	@class PlacementGridRuntime
	Resolves client-side world grid geometry and tile descriptors for placement helpers.
	@client
]=]
local PlacementGridRuntime = {}

local cachedGridSpec: GridSpec? = nil
local cachedSidePocketParts: { BasePart }? = nil
local cachedSidePocketCoordKeySet: { [string]: boolean }? = nil
local cachedSidePocketResourceByKey: { [string]: string }? = nil
local cachedPlacementProhibitedParts: { BasePart }? = nil
local cachedPlacementProhibitedCoordKeySet: { [string]: boolean }? = nil
local GRID_PART_WAIT_TIMEOUT_SECONDS = 30
local GRID_PART_POLL_INTERVAL_SECONDS = 0.25
local PLACEMENT_GRIDS_PATH = "Workspace.Map.Game.Environment.Zones.PlacementGrids"
local SIDE_POCKETS_PATH = "Workspace.Map.Game.Environment.Zones.SidePockets"
local PLACEMENT_PROHIBITED_PATH = "Workspace.Map.Game.Environment.Zones.PlacementProhibited"

-- [Private Helpers]

-- Resolves a dot-path into an instance so the client can find authored world markers without hardcoding references.
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

-- Waits for the authoritative placement grid part because the client may initialize before the map finishes loading.
local function _GetGridPart(): BasePart
	local deadline = os.clock() + GRID_PART_WAIT_TIMEOUT_SECONDS
	local lastDebugPrintAt = 0

	repeat
		local gridContainer = _ResolvePath(PLACEMENT_GRIDS_PATH)
		local gridInstance = nil :: BasePart?
		if gridContainer ~= nil then
			if gridContainer:IsA("BasePart") and gridContainer.Name == WorldConfig.GRID_PART_NAME then
				gridInstance = gridContainer
			else
				for _, descendant in ipairs(gridContainer:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.Name == WorldConfig.GRID_PART_NAME then
						gridInstance = descendant
						break
					end
				end
			end
		end

		-- Fallback for map variants where the zone path differs but the marker name is still canonical.
		if gridInstance == nil then
			local fallback = Workspace:FindFirstChild(WorldConfig.GRID_PART_NAME, true)
			if fallback ~= nil and fallback:IsA("BasePart") then
				gridInstance = fallback
			end
		end

		if gridInstance ~= nil then
			print(("[PlacementGridDebug] Found grid part '%s'"):format(gridInstance:GetFullName()))
			return gridInstance
		end

		local now = os.clock()
		if now - lastDebugPrintAt >= 1 then
			lastDebugPrintAt = now
			print(("[PlacementGridDebug] Waiting for PlacementGrid. strictPathFound=%s fallbackFound=%s"):format(
				tostring(gridContainer ~= nil),
				tostring(Workspace:FindFirstChild(WorldConfig.GRID_PART_NAME, true) ~= nil)
			))
		end

		task.wait(GRID_PART_POLL_INTERVAL_SECONDS)
	until os.clock() >= deadline

	error(("PlacementGridRuntime: missing PlacementGrid part after %ds. Path=%s Name=%s"):format(
		GRID_PART_WAIT_TIMEOUT_SECONDS,
		PLACEMENT_GRIDS_PATH,
		WorldConfig.GRID_PART_NAME
	))
end

-- Collects authored side-pocket parts so tile zoning can be derived from map markers instead of hardcoded coordinates.
local function _GetSidePocketParts(): { BasePart }
	local parts = {}
	local container = _ResolvePath(SIDE_POCKETS_PATH)
	if container ~= nil then
		if container:IsA("BasePart") then
			table.insert(parts, container)
		else
			for _, instance in ipairs(container:GetDescendants()) do
				if instance:IsA("BasePart") then
					table.insert(parts, instance)
				end
			end
		end
	end

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

-- Collects authored prohibited-placement parts so build denial can be driven by map markers.
local function _GetPlacementProhibitedParts(): { BasePart }
	local parts = {}
	local container = _ResolvePath(PLACEMENT_PROHIBITED_PATH)
	if container ~= nil then
		if container:IsA("BasePart") then
			table.insert(parts, container)
		else
			for _, instance in ipairs(container:GetDescendants()) do
				if instance:IsA("BasePart") then
					table.insert(parts, instance)
				end
			end
		end
	end

	if #parts == 0 then
		local fallback = Workspace:FindFirstChild("PlacementProhibited", true)
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

-- Derives the immutable grid specification from the authoritative grid part dimensions.
local function _BuildGridSpec(gridPart: BasePart): GridSpec
	local tileSize = WorldConfig.TILE_SIZE
	local gridSize = gridPart.Size

	assert(tileSize > 0, "PlacementGridRuntime: invalid tile size")
	assert(gridSize.X > 0 and gridSize.Z > 0, "PlacementGridRuntime: invalid PlacementGrid dimensions")
	assert(math.abs(gridSize.X / tileSize - math.floor(gridSize.X / tileSize)) < 1e-6, "PlacementGridRuntime: invalid PlacementGrid dimensions")
	assert(math.abs(gridSize.Z / tileSize - math.floor(gridSize.Z / tileSize)) < 1e-6, "PlacementGridRuntime: invalid PlacementGrid dimensions")

	local gridCols = math.floor(gridSize.X / tileSize)
	local gridRows = math.floor(gridSize.Z / tileSize)
	assert(gridCols >= 1 and gridRows >= 1, "PlacementGridRuntime: invalid PlacementGrid dimensions")

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

-- [Public API]

--[=[
	Returns the cached grid spec so repeated coordinate conversions do not rebuild map metadata.
	@within PlacementGridRuntime
	@return GridSpec -- The immutable grid specification.
]=]
function PlacementGridRuntime.GetGridSpec(): GridSpec
	if cachedGridSpec ~= nil then
		return cachedGridSpec
	end

	local spec = _BuildGridSpec(_GetGridPart())
	cachedGridSpec = spec
	return spec
end

-- Returns the cached side-pocket part list because authored map markers do not change during play.
local function _GetSidePocketPartsCached(): { BasePart }
	if cachedSidePocketParts ~= nil then
		return cachedSidePocketParts
	end

	local parts = _GetSidePocketParts()
	cachedSidePocketParts = parts
	return parts
end

-- Returns cached placement-prohibited marker parts.
local function _GetPlacementProhibitedPartsCached(): { BasePart }
	if cachedPlacementProhibitedParts ~= nil then
		return cachedPlacementProhibitedParts
	end

	local parts = _GetPlacementProhibitedParts()
	cachedPlacementProhibitedParts = parts
	return parts
end

--[=[
	Converts a grid coordinate into a world position using the cached grid spec.
	@within PlacementGridRuntime
	@param coord GridCoord -- Grid coordinate to convert.
	@return Vector3 -- World-space tile center.
]=]
function PlacementGridRuntime.CoordToWorld(coord: GridCoord): Vector3
	local spec = PlacementGridRuntime.GetGridSpec()
	local localX = -spec.gridSize.X * 0.5 + spec.tileSize * 0.5 + (coord.col - 1) * spec.tileSize
	local localZ = -spec.gridSize.Z * 0.5 + spec.tileSize * 0.5 + (coord.row - 1) * spec.tileSize
	return spec.gridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

--[=[
	Converts a world position back into a grid coordinate when the point is inside the grid bounds.
	@within PlacementGridRuntime
	@param worldPos Vector3 -- World position to resolve.
	@return GridCoord? -- The resolved grid coordinate or nil if the point is outside the grid.
]=]
function PlacementGridRuntime.WorldToCoord(worldPos: Vector3): GridCoord?
	local spec = PlacementGridRuntime.GetGridSpec()
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

-- Builds the fallback resource label for side-pocket tiles when the authored part does not specify one.
local function _BuildResourceType(col: number): string
	return if (col / WorldConfig.SIDE_POCKET_COLUMN_INTERVAL) % 2 == 0 then "Crystal" else "Metal"
end

-- Builds a stable lookup key for a grid coordinate so cached tile membership can stay table-driven.
local function _GetCoordKey(row: number, col: number): string
	return (`{row}_{col}`)
end

-- Reads the authored resource type from a side-pocket marker part when the map explicitly defines one.
local function _GetPartResourceType(part: BasePart): string?
	local attributeValue = part:GetAttribute("ResourceType")
	if type(attributeValue) == "string" and #attributeValue > 0 then
		return attributeValue
	end
	return nil
end

-- Checks whether a world point falls within a part's XZ footprint, ignoring height so thin markers still register.
local function _IsInsidePartXZ(part: BasePart, worldPoint: Vector3): boolean
	local localPoint = part.CFrame:PointToObjectSpace(worldPoint)
	local halfSize = part.Size * 0.5
	local epsilon = 1e-4
	return math.abs(localPoint.X) <= halfSize.X + epsilon and math.abs(localPoint.Z) <= halfSize.Z + epsilon
end

-- Tests whether a tile center overlaps a marker part by sampling the tile corners and center.
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

-- Finds the nearest non-lane grid coordinate so the client can recover when a marker sits slightly off-grid.
local function _ResolveNearestEligibleCoord(worldPos: Vector3, spec: GridSpec): GridCoord?
	local bestCoord: GridCoord? = nil
	local bestDistanceSquared = math.huge

	for row = 1, spec.gridRows do
		if row ~= spec.laneRow then
			for col = 1, spec.gridCols do
				local tileCenter = PlacementGridRuntime.CoordToWorld({
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

-- Resolves side-pocket membership and optional resource overrides from authored marker parts.
local function _GetResolvedSidePocketTiles(spec: GridSpec): ({ [string]: boolean }, { [string]: string })
	if cachedSidePocketCoordKeySet ~= nil and cachedSidePocketResourceByKey ~= nil then
		return cachedSidePocketCoordKeySet, cachedSidePocketResourceByKey
	end

	local coordKeySet = {} :: { [string]: boolean }
	local resourceByKey = {} :: { [string]: string }

	for _, part in ipairs(_GetSidePocketPartsCached()) do
		local matchedAnyTile = false
		local partResourceType = _GetPartResourceType(part)

		for row = 1, spec.gridRows do
			if row ~= spec.laneRow then
				for col = 1, spec.gridCols do
					local tileCenter = PlacementGridRuntime.CoordToWorld({
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
			local nearestCoord = _ResolveNearestEligibleCoord(part.Position, spec)
			if nearestCoord ~= nil then
				local coordKey = _GetCoordKey(nearestCoord.row, nearestCoord.col)
				coordKeySet[coordKey] = true
				if partResourceType ~= nil then
					resourceByKey[coordKey] = partResourceType
				end
			end
		end
	end

	cachedSidePocketCoordKeySet = coordKeySet
	cachedSidePocketResourceByKey = resourceByKey
	return coordKeySet, resourceByKey
end

-- Resolves placement-prohibited tile membership from authored marker parts.
local function _GetResolvedPlacementProhibitedTiles(spec: GridSpec): { [string]: boolean }
	if cachedPlacementProhibitedCoordKeySet ~= nil then
		return cachedPlacementProhibitedCoordKeySet
	end

	local coordKeySet = {} :: { [string]: boolean }

	for _, part in ipairs(_GetPlacementProhibitedPartsCached()) do
		local matchedAnyTile = false

		for row = 1, spec.gridRows do
			for col = 1, spec.gridCols do
				local tileCenter = PlacementGridRuntime.CoordToWorld({
					row = row,
					col = col,
				})

				if _TileOverlapsPartXZ(part, tileCenter, spec) then
					local coordKey = _GetCoordKey(row, col)
					coordKeySet[coordKey] = true
					matchedAnyTile = true
				end
			end
		end

		-- Reconcile marker parts that are near the grid but miss tile overlap.
		if not matchedAnyTile then
			local nearestCoord = _ResolveNearestEligibleCoord(part.Position, spec)
			if nearestCoord ~= nil then
				local coordKey = _GetCoordKey(nearestCoord.row, nearestCoord.col)
				coordKeySet[coordKey] = true
			end
		end
	end

	cachedPlacementProhibitedCoordKeySet = coordKeySet
	return coordKeySet
end

--[=[
	Returns the tile descriptor for a grid coordinate so placement code can filter by zone and resource type.
	@within PlacementGridRuntime
	@param row number -- Grid row to inspect.
	@param col number -- Grid column to inspect.
	@return TileDescriptor? -- The resolved tile descriptor or nil when the coordinate is out of bounds.
]=]
function PlacementGridRuntime.GetTileDescriptor(row: number, col: number): TileDescriptor?
	local spec = PlacementGridRuntime.GetGridSpec()
	if row < 1 or row > spec.gridRows or col < 1 or col > spec.gridCols then
		return nil
	end

	local zone: ZoneType = "buildable"
	local resourceType: string? = nil
	if row == spec.laneRow then
		zone = "lane"
	else
		local coordKey = _GetCoordKey(row, col)
		local sidePocketCoordKeySet, sidePocketResourceByKey = _GetResolvedSidePocketTiles(spec)
		if sidePocketCoordKeySet[coordKey] == true then
			zone = "side_pocket"
			resourceType = sidePocketResourceByKey[coordKey] or _BuildResourceType(col)
		end
	end

	local coordKey = _GetCoordKey(row, col)
	local prohibitedCoordKeySet = _GetResolvedPlacementProhibitedTiles(spec)
	local isPlacementProhibited = prohibitedCoordKeySet[coordKey] == true

	return table.freeze({
		zone = zone,
		resourceType = resourceType,
		isPlacementProhibited = isPlacementProhibited,
	})
end

return table.freeze(PlacementGridRuntime)
