--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type TileDescriptor = WorldTypes.TileDescriptor
type GridSpec = WorldTypes.GridSpec

local PlacementGridRuntime = {}

local cachedGridSpecsById: { [string]: GridSpec }? = nil
local cachedGridSpecList: { GridSpec }? = nil
local cachedResourceParts: { BasePart }? = nil
local cachedResourceCoordKeySet: { [string]: boolean }? = nil
local cachedResourceTypeByKey: { [string]: string }? = nil
local cachedPlacementProhibitedParts: { BasePart }? = nil
local cachedPlacementProhibitedCoordKeySet: { [string]: boolean }? = nil
local GRID_PART_WAIT_TIMEOUT_SECONDS = 30
local GRID_PART_POLL_INTERVAL_SECONDS = 0.25
local PLACEMENT_GRIDS_PATH = "Workspace.Map.Game.Environment.Zones.PlacementGrids"
local RESOURCE_ZONE_PATH = "Workspace.Map.Game.Environment.Zones." .. WorldConfig.RESOURCE_ZONE_NAME
local PLACEMENT_PROHIBITED_PATH = "Workspace.Map.Game.Environment.Zones.PlacementProhibited"

local function _ResetCache()
	cachedGridSpecsById = nil
	cachedGridSpecList = nil
	cachedResourceParts = nil
	cachedResourceCoordKeySet = nil
	cachedResourceTypeByKey = nil
	cachedPlacementProhibitedParts = nil
	cachedPlacementProhibitedCoordKeySet = nil
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

local function _GetGridParts(): { BasePart }
	local deadline = os.clock() + GRID_PART_WAIT_TIMEOUT_SECONDS

	repeat
		local parts = {}
		local gridContainer = _ResolvePath(PLACEMENT_GRIDS_PATH)
		if gridContainer ~= nil then
			if gridContainer:IsA("BasePart") and gridContainer.Name == WorldConfig.GRID_PART_NAME then
				table.insert(parts, gridContainer)
			else
				for _, descendant in ipairs(gridContainer:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.Name == WorldConfig.GRID_PART_NAME then
						table.insert(parts, descendant)
					end
				end
			end
		end

		if #parts == 0 then
			for _, descendant in ipairs(Workspace:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Name == WorldConfig.GRID_PART_NAME then
					table.insert(parts, descendant)
				end
			end
		end

		if #parts > 0 then
			return parts
		end

		task.wait(GRID_PART_POLL_INTERVAL_SECONDS)
	until os.clock() >= deadline

	error(("PlacementGridRuntime: missing PlacementGrid part after %ds. Path=%s Name=%s"):format(
		GRID_PART_WAIT_TIMEOUT_SECONDS,
		PLACEMENT_GRIDS_PATH,
		WorldConfig.GRID_PART_NAME
	))
end

local function _GetResourceParts(): { BasePart }
	local parts = {}
	local container = _ResolvePath(RESOURCE_ZONE_PATH)
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
		local fallback = Workspace:FindFirstChild(WorldConfig.RESOURCE_ZONE_NAME, true)
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

local function _BuildGridSpec(gridPart: BasePart): GridSpec
	local tileSize = WorldConfig.TILE_SIZE
	local gridSize = gridPart.Size
	local gridId = gridPart:GetAttribute("GridId")

	assert(type(gridId) == "string" and #gridId > 0, "PlacementGridRuntime: PlacementGrid is missing GridId")
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
		GridId = gridId,
		GridCFrame = gridPart.CFrame,
		GridSize = gridSize,
		TileSize = tileSize,
		GridRows = gridRows,
		GridCols = gridCols,
		LaneRow = laneRow,
		SidePocketRows = table.freeze(sidePocketRows),
	})
end

local function _IsOverlappingXZ(firstPart: BasePart, secondPart: BasePart): boolean
	local firstHalfSize = firstPart.Size * 0.5
	local secondHalfSize = secondPart.Size * 0.5
	local firstCenter = firstPart.Position
	local secondCenter = secondPart.Position
	local epsilon = 1e-4

	return math.abs(firstCenter.X - secondCenter.X) < (firstHalfSize.X + secondHalfSize.X - epsilon)
		and math.abs(firstCenter.Z - secondCenter.Z) < (firstHalfSize.Z + secondHalfSize.Z - epsilon)
end

function PlacementGridRuntime.GetGridSpecs(): { [string]: GridSpec }
	if cachedGridSpecsById ~= nil then
		return cachedGridSpecsById
	end

	local gridParts = _GetGridParts()
	local specsById = {} :: { [string]: GridSpec }
	local specList = {} :: { GridSpec }
	local partById = {} :: { [string]: BasePart }

	for _, gridPart in ipairs(gridParts) do
		local spec = _BuildGridSpec(gridPart)
		assert(specsById[spec.GridId] == nil, "PlacementGridRuntime: duplicate GridId")
		specsById[spec.GridId] = spec
		partById[spec.GridId] = gridPart
		table.insert(specList, spec)
	end

	table.sort(specList, function(left: GridSpec, right: GridSpec): boolean
		return left.GridId < right.GridId
	end)

	for firstIndex = 1, #specList do
		local firstSpec = specList[firstIndex]
		local firstPart = partById[firstSpec.GridId]
		for secondIndex = firstIndex + 1, #specList do
			local secondSpec = specList[secondIndex]
			local secondPart = partById[secondSpec.GridId]
			if firstPart ~= nil and secondPart ~= nil then
				assert(not _IsOverlappingXZ(firstPart, secondPart), "PlacementGridRuntime: overlapping PlacementGrid parts are not supported")
			end
		end
	end

	cachedGridSpecsById = specsById
	cachedGridSpecList = specList
	return specsById
end

function PlacementGridRuntime.GetGridSpecList(): { GridSpec }
	if cachedGridSpecList ~= nil then
		return cachedGridSpecList
	end

	PlacementGridRuntime.GetGridSpecs()
	return cachedGridSpecList or {}
end

function PlacementGridRuntime.GetGridSpec(gridId: string): GridSpec?
	return PlacementGridRuntime.GetGridSpecs()[gridId]
end

function PlacementGridRuntime.ResetCache()
	_ResetCache()
end

local function _GetResourcePartsCached(): { BasePart }
	if cachedResourceParts ~= nil then
		return cachedResourceParts
	end

	local parts = _GetResourceParts()
	cachedResourceParts = parts
	return parts
end

local function _GetPlacementProhibitedPartsCached(): { BasePart }
	if cachedPlacementProhibitedParts ~= nil then
		return cachedPlacementProhibitedParts
	end

	local parts = _GetPlacementProhibitedParts()
	cachedPlacementProhibitedParts = parts
	return parts
end

function PlacementGridRuntime.CoordToWorld(coord: GridCoord): Vector3
	local spec = PlacementGridRuntime.GetGridSpec(coord.GridId)
	assert(spec ~= nil, "PlacementGridRuntime: unknown GridId")
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (coord.Col - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (coord.Row - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

function PlacementGridRuntime.WorldToCoord(worldPos: Vector3): GridCoord?
	for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
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
	return (`{coord.GridId}:{coord.Row}:{coord.Col}`)
end

local function _GetPartResourceType(part: BasePart): string?
	if #part.Name > 0 then
		return part.Name
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

local function _ResolveNearestEligibleCoord(worldPos: Vector3, spec: GridSpec): GridCoord?
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
				local tileCenter = PlacementGridRuntime.CoordToWorld(coord)
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

local function _GetResolvedResourceTiles(): ({ [string]: boolean }, { [string]: string })
	if cachedResourceCoordKeySet ~= nil and cachedResourceTypeByKey ~= nil then
		return cachedResourceCoordKeySet, cachedResourceTypeByKey
	end

	local coordKeySet = {} :: { [string]: boolean }
	local resourceTypeByKey = {} :: { [string]: string }

	for _, part in ipairs(_GetResourcePartsCached()) do
		local partResourceType = _GetPartResourceType(part)
		if partResourceType == nil then
			continue
		end

		local matchedAnyTile = false
		for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
			for row = 1, spec.GridRows do
				if row ~= spec.LaneRow then
					for col = 1, spec.GridCols do
						local coord = {
							GridId = spec.GridId,
							Row = row,
							Col = col,
						}
						local tileCenter = PlacementGridRuntime.CoordToWorld(coord)
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
			for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
				local nearestCoord = _ResolveNearestEligibleCoord(part.Position, spec)
				if nearestCoord ~= nil then
					local tileCenter = PlacementGridRuntime.CoordToWorld(nearestCoord)
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

	cachedResourceCoordKeySet = coordKeySet
	cachedResourceTypeByKey = resourceTypeByKey
	return coordKeySet, resourceTypeByKey
end

local function _GetResolvedPlacementProhibitedTiles(): { [string]: boolean }
	if cachedPlacementProhibitedCoordKeySet ~= nil then
		return cachedPlacementProhibitedCoordKeySet
	end

	local coordKeySet = {} :: { [string]: boolean }

	for _, part in ipairs(_GetPlacementProhibitedPartsCached()) do
		local matchedAnyTile = false
		for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
			for row = 1, spec.GridRows do
				for col = 1, spec.GridCols do
					local coord = {
						GridId = spec.GridId,
						Row = row,
						Col = col,
					}
					local tileCenter = PlacementGridRuntime.CoordToWorld(coord)
					if _TileOverlapsPartXZ(part, tileCenter, spec) then
						coordKeySet[_GetCoordKey(coord)] = true
						matchedAnyTile = true
					end
				end
			end
		end

		if not matchedAnyTile then
			local bestCoord = nil :: GridCoord?
			local bestDistanceSquared = math.huge
			for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
				local nearestCoord = _ResolveNearestEligibleCoord(part.Position, spec)
				if nearestCoord ~= nil then
					local tileCenter = PlacementGridRuntime.CoordToWorld(nearestCoord)
					local delta = tileCenter - part.Position
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

	cachedPlacementProhibitedCoordKeySet = coordKeySet
	return coordKeySet
end

function PlacementGridRuntime.GetTileDescriptor(coord: GridCoord): TileDescriptor?
	local spec = PlacementGridRuntime.GetGridSpec(coord.GridId)
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
		local resourceCoordKeySet, resourceTypeByKey = _GetResolvedResourceTiles()
		local coordKey = _GetCoordKey(coord)
		if resourceCoordKeySet[coordKey] == true then
			zone = "side_pocket"
			resourceType = resourceTypeByKey[coordKey]
		end
	end

	return table.freeze({
		Zone = zone,
		ResourceType = resourceType,
		IsPlacementProhibited = _GetResolvedPlacementProhibitedTiles()[_GetCoordKey(coord)] == true,
	})
end

return table.freeze(PlacementGridRuntime)
