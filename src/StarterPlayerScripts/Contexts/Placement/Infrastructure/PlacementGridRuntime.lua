--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type TileDescriptor = WorldTypes.TileDescriptor
type ZoneType = WorldTypes.ZoneType
type GridSpec = WorldTypes.GridSpec

local PlacementGridRuntime = {}

local cachedGridSpec: GridSpec? = nil
local cachedSidePocketParts: { BasePart }? = nil
local cachedSidePocketCoordKeySet: { [string]: boolean }? = nil
local cachedSidePocketResourceByKey: { [string]: string }? = nil
local GRID_PART_WAIT_TIMEOUT_SECONDS = 30
local GRID_PART_POLL_INTERVAL_SECONDS = 0.25

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
			child = current:WaitForChild(segment, 5)
		end
		if child == nil then
			return nil
		end
		current = child
	end
	return current
end

local function _GetGridPart(): BasePart
	local deadline = os.clock() + GRID_PART_WAIT_TIMEOUT_SECONDS

	repeat
		local gridInstance = _ResolvePath(WorldConfig.GRID_PART_PATH)
		if gridInstance == nil then
			gridInstance = Workspace:FindFirstChild("PlacementGrid", true)
		end

		if gridInstance ~= nil and gridInstance:IsA("BasePart") then
			return gridInstance
		end

		task.wait(GRID_PART_POLL_INTERVAL_SECONDS)
	until os.clock() >= deadline

	error("PlacementGridRuntime: missing PlacementGrid part")
end

local function _GetSidePocketParts(): { BasePart }
	local parts = {}
	local container = _ResolvePath(WorldConfig.SIDE_POCKETS_PATH)
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

function PlacementGridRuntime.GetGridSpec(): GridSpec
	if cachedGridSpec ~= nil then
		return cachedGridSpec
	end

	local spec = _BuildGridSpec(_GetGridPart())
	cachedGridSpec = spec
	return spec
end

local function _GetSidePocketPartsCached(): { BasePart }
	if cachedSidePocketParts ~= nil then
		return cachedSidePocketParts
	end

	local parts = _GetSidePocketParts()
	cachedSidePocketParts = parts
	return parts
end

function PlacementGridRuntime.CoordToWorld(coord: GridCoord): Vector3
	local spec = PlacementGridRuntime.GetGridSpec()
	local localX = -spec.gridSize.X * 0.5 + spec.tileSize * 0.5 + (coord.col - 1) * spec.tileSize
	local localZ = -spec.gridSize.Z * 0.5 + spec.tileSize * 0.5 + (coord.row - 1) * spec.tileSize
	return spec.gridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

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

function PlacementGridRuntime.GetTileDescriptor(row: number, col: number): TileDescriptor?
	local spec = PlacementGridRuntime.GetGridSpec()
	if row < 1 or row > spec.gridRows or col < 1 or col > spec.gridCols then
		return nil
	end

	local zone: ZoneType = "blocked"
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

	return table.freeze({
		zone = zone,
		resourceType = resourceType,
	})
end

return table.freeze(PlacementGridRuntime)
