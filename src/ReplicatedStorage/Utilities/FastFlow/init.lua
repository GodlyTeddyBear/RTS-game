--[[
	FastFlow by bob_factory (UserId: 271942569)
	Grid-based flowfield generation on single-level maps
--]]

local PriorityQueue = script:WaitForChild("PriorityQueue")
local Queue = script:WaitForChild("Queue")
local Grid = script:WaitForChild("Grid")

local newColor = Color3.fromRGB
local newCFrameLook = CFrame.lookAt
local newCFrame = CFrame.new
local newVector2 = Vector2.new
local newVector3 = Vector3.new
local insert = table.insert
local create = table.create
local round = math.round
local floor = math.floor
local ceil = math.ceil
local sqrt = math.sqrt
local tan = math.tan
local rad = math.rad
local abs = math.abs
local max = math.max
local min = math.min

local ZERO_VECTOR = newVector2(0, 0)
local ONE_VECTOR = newVector2(1, 1)
local WALL_OFFSET = tan(rad(45 / 2))
local SQRT2 = sqrt(2)
local EPSILON = 10e-5
local LARGE = 10e5
local EPSILON_VISUAL = 5e-2
local GREY = newColor(100, 100, 100)

local DEFAULT_CHUNK_SIZE = 4
local ADJACENT = {
	newVector2(1, 0),
	newVector2(0, 1),
	newVector2(-1, 0),
	newVector2(0, -1),
}
local DIAGONAL = {
	newVector2(1, 0),
	newVector2(0, 1),
	newVector2(-1, 0),
	newVector2(0, -1),
	newVector2(1, 1),
	newVector2(-1, 1),
	newVector2(-1, -1),
	newVector2(1, -1),
}

local function warnNotPreprocessed()
	warn("Starting positions ignored and pruning optimizations disabled because pathfinder preprocessing was omitted")
end
local function warnInvalidEndpoint(details: string?)
	if details and #details > 0 then
		warn(`Start or goal position inside a wall, on the map border, or out of bounds | {details}`)
		return
	end
	warn("Start or goal position inside a wall, on the map border, or out of bounds")
end
local function warnDecimalCoords()
	warn("Decimal coordinates used - please round inputs to the nearest integer")
end
local function warnInvalidPath()
	warn("No path found")
end
local function roundVector(vec)
	return newVector2(round(vec.X), round(vec.Y))
end
local function mirrorAbsVector(vec)
	return newVector2(abs(vec.Y), abs(vec.X))
end
local function forceIntegerCoords(pos)
	local int = roundVector(pos)
	if int ~= pos then
		warnDecimalCoords()
	end
	return int
end
local function vector2ToVector3(vec, yLevel)
	return newVector3(vec.X, yLevel or 0, vec.Y)
end

local PriorityQueue = require(PriorityQueue)
local Queue = require(Queue)
local Grid = require(Grid)
local FastFlow = {}
local Pathfinder = {}
local Flowfield = {}

Pathfinder.__index = Pathfinder
Flowfield.__index = Flowfield
FastFlow.Grid = Grid

-- Creates or returns the Folder + Part used by Pathfinder:Visualize.
-- VisualizeParts is parented to Workspace; the Part template stays under this ModuleScript for cloning.
function FastFlow.EnsureVisualizerReferences(): (Folder, Part)
	local folder = script:FindFirstChild("VisualizeParts")
	if folder == nil or not folder:IsA("Folder") then
		if folder ~= nil then
			folder:Destroy()
		end
		local inWorkspace = workspace:FindFirstChild("VisualizeParts")
		if inWorkspace ~= nil and inWorkspace:IsA("Folder") then
			folder = inWorkspace
		else
			folder = Instance.new("Folder")
			folder.Name = "VisualizeParts"
		end
	end
	folder.Parent = workspace

	local template = script:FindFirstChild("Visualize")
	if template == nil or not template:IsA("BasePart") then
		if template ~= nil then
			template:Destroy()
		end
		local part = Instance.new("Part")
		part.Name = "Visualize"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.Neon
		part.Size = newVector3(1, 0.05, 1)
		part.Transparency = 0.5
		part.Parent = script
		template = part
	end

	return folder :: Folder, template :: Part
end

export type Pathfinder = typeof(setmetatable({}, Pathfinder))
export type Flowfield = typeof(setmetatable({}, Flowfield))
export type Grid = typeof(setmetatable({}, Grid))

-- Returns a new pathfinder using the map given by walls. Mark intraversable cells as true and leave traversable cells as nil. Cells on the map border must be intraversable (the constructor automatically does this).
-- Chunks (for pruning purposes) will have a width of chunkSize * 2 + 1. This is to ensure widths are odd integers.
-- If omitPreprocessing is true, preprocessing will be omitted. This means pruning functionalities will be disabled and border cells will not be automatically marked as intraversable.
function FastFlow.NewPathfinder(Walls: Grid, chunkSize: number?, omitPreprocessing: boolean?): Pathfinder
	local newPathfinder = {}
	setmetatable(newPathfinder, Pathfinder)

	local chunkSize = chunkSize or DEFAULT_CHUNK_SIZE
	local chunkWidth = chunkSize * 2 + 1
	local size = Walls._Size
	local width = size * 2 + 1

	newPathfinder._Size = size
	newPathfinder._Width = width
	newPathfinder._ChunkSize = chunkSize
	newPathfinder._ChunkWidth = chunkWidth
	newPathfinder._Walls = Walls

	if not omitPreprocessing then
		newPathfinder:SetupBorders()
		newPathfinder:SetupPruning()
	end
	return newPathfinder
end

-- Returns a flowfield that leads to goal. Integer coordinates must be used for goal.
-- If startPositions are provided, the flowfield will be pruned and only generate in relevant cells. If preprocessing was omitted, a warning will be thrown and startPositions will be ignored. If no path is found, a warning will be thrown and an empty flowfield will be returned.
function Pathfinder:GenerateFlowfield(goal: Vector2, startPositions: { Vector2 }?): Flowfield
	local Pathfinder = self
	local Walls = self._Walls
	if startPositions and Pathfinder._Portals == nil then
		startPositions = nil
		warnNotPreprocessed()
	end

	local goal = forceIntegerCoords(goal)
	local Path = self:_NewFlowfield(goal, startPositions)
	Pathfinder:_FloodfillFlowfield({ Walls:_GetCellIndex(goal) }, Path, DIAGONAL, not startPositions)
	return Path
end

-- Extends the pruned flowfield Path to an adjacent chunk to include the cell start. Integer coordinates must be used for start.
function Pathfinder:MergeFlowfield(Path: Flowfield, start: Vector2): Flowfield
	local Pathfinder = self
	local Regions = self._Regions
	local Distances = Path._Distances

	local start = forceIntegerCoords(start)
	local start = Regions:_GetCellIndex(start)
	local startRegion = Regions._Grid[start]
	local border = {}

	if not startRegion then
		local startPos = Regions:_GetCellPos(start)
		warnInvalidEndpoint(
			`MergeFlowfield start=({startPos.X},{startPos.Y}) region=nil wall={tostring(Pathfinder._Walls._Grid[start] == true)}`
		)
		return
	end

	if type(Path._Chunks) == "table" then
		Pathfinder:_Floodfill({ start }, function(visitedIndex)
			if Distances._Grid[visitedIndex] then
				insert(border, visitedIndex)
			end
			return Regions._Grid[visitedIndex] == startRegion
		end)

		Path._Chunks[startRegion] = true
		Pathfinder:_FloodfillFlowfield(border, Path, DIAGONAL, true)
	end
	return Path
end

-- Returns pos if it is open. Otherwise, returns the closest open neighbor. Returns nil if no open cells are found. Decimal coordinates can be used for pos.
function Pathfinder:FindOpenCell(pos: Vector2): Vector2
	local Walls = self._Walls

	local floatPos = pos
	local pos = roundVector(pos)
	local posIndex = Walls:_GetCellIndex(pos)

	if Walls._Grid[posIndex] then
		local openNeighbor = nil
		local openNeighborDist = LARGE

		Walls:_ForNeighbors(posIndex, DIAGONAL, function(visitedIndex, dxyIndex)
			local visitedPos = pos + DIAGONAL[dxyIndex]
			local distance = (visitedPos - floatPos).Magnitude

			if
				openNeighborDist > distance
				and Walls._Grid[visitedIndex] == nil
				and Walls:IsCellInBounds(visitedPos)
			then
				openNeighbor = visitedPos
				openNeighborDist = distance
			end
		end)
		return openNeighbor
	else
		return pos
	end
end

-- Visualizes the pathfinder's walls and HPA graph, where each cell has width cellWidth and is displayed at world height yLevel
function Pathfinder:Visualize(
	cellWidth: number?,
	yLevel: number?,
	showWalls: boolean?,
	showCellGrid: boolean?,
	showChunkGrid: boolean?,
	showHPA: boolean?
)
	local folder, template = FastFlow.EnsureVisualizerReferences()

	local Portals = self._Portals
	local Walls = self._Walls

	local chunkWidth = self._ChunkWidth
	local width = self._Width
	local size = self._Size

	local cellWidth = cellWidth or 1
	local cellHeight = max(cellWidth * EPSILON_VISUAL, EPSILON_VISUAL)
	local lineWidth = cellWidth * EPSILON_VISUAL
	local yLevel = yLevel or 0

	for coord = -size + 0.5, size - 0.5, 1 do
		local gridLineWidth = showCellGrid and lineWidth or 0
		if showChunkGrid and coord % chunkWidth == chunkWidth / 2 then
			gridLineWidth = lineWidth * 2
		end

		if gridLineWidth > 0 then
			local gridLineX = template:Clone()
			gridLineX.CFrame = newCFrame(0, yLevel, coord * cellWidth)
			gridLineX.Size = newVector3(cellWidth * width, cellHeight / 2, gridLineWidth)
			gridLineX.Color = GREY
			gridLineX.Parent = folder

			local gridLineY = template:Clone()
			gridLineY.CFrame = newCFrame(coord * cellWidth, yLevel, 0)
			gridLineY.Size = newVector3(gridLineWidth, cellHeight / 2, cellWidth * width)
			gridLineY.Color = GREY
			gridLineY.Parent = folder
		end
	end

	if showWalls then
		for index, _ in Walls._Grid do
			local pos = Walls:_GetCellPos(index)

			local square = template:Clone()
			square.CFrame = newCFrame(vector2ToVector3(pos * cellWidth, yLevel))
			square.Size = newVector3(cellWidth, cellHeight, cellWidth)
			square.Parent = folder
		end
	end

	if showHPA and Portals ~= nil then
		for index1, neighbors in Portals._Grid do
			for index2, _ in neighbors do
				local pos1 = vector2ToVector3(Portals:_GetCellPos(index1) * cellWidth, yLevel)
				local pos2 = vector2ToVector3(Portals:_GetCellPos(index2) * cellWidth, yLevel)

				local line = template:Clone()
				line.CFrame = newCFrameLook((pos1 + pos2) / 2, pos2)
				line.Size = newVector3(lineWidth, cellHeight, (pos1 - pos2).Magnitude)
				line.Parent = folder
			end
		end
	end
end

-- Marks the pathfinder’s border cells to be intraversable. This is already done automatically during preprocessing.
function Pathfinder:SetupBorders()
	local Pathfinder = self
	local size = self._Size

	for _, dxy in ADJACENT do
		local center = dxy * size
		local diagonal = mirrorAbsVector(dxy) * size
		Grid._ForBox(center - diagonal, center + diagonal, function(pos)
			Pathfinder._Walls:SetCell(pos, true)
		end)
	end
end

-- Generates the high-level HPA graph used for pruning optimizations. This is already done automatically during preprocessing.
function Pathfinder:SetupPruning()
	local Pathfinder = self
	local chunkWidth = self._ChunkWidth
	local chunkSize = self._ChunkSize
	local size = self._Size

	Pathfinder._NumRegions = 0
	Pathfinder._RegionPortals = {}
	Pathfinder._Portals = Grid.New(size)
	Pathfinder._Regions = Grid.New(size)

	local chunkCorner = ceil((size - chunkSize) / chunkWidth) * ONE_VECTOR
	Grid._ForBox(-chunkCorner, chunkCorner, function(chunkPos)
		if (chunkPos.X + chunkPos.Y) % 2 == 0 then
			Pathfinder:_SetupPortals(chunkPos)
		end
	end)
	Grid._ForBox(-chunkCorner, chunkCorner, function(chunkPos)
		Pathfinder:_ConnectPortals(chunkPos)
	end)
end

-- Returns a unit vector representing the flowfield’s direction at pos. Integer coordinates must be used for pos. If the flowfield is pruned and pos is inside an omitted chunk, nil will be returned.
function Flowfield:GetDirection(pos: Vector2): Vector2
	local Flowfield = self._Flowfield
	local Distances = self._Distances
	local index = Distances:_GetCellIndex(forceIntegerCoords(pos))

	if self:_IsCellInChunks(index) then
		local dir = Flowfield._Grid[index]
		if not dir then
			dir = ZERO_VECTOR

			local center = Distances._Grid[index]
			if center then
				Distances:_ForNeighbors(index, ADJACENT, function(visitedIndex, dxyIndex)
					local dist = Distances._Grid[visitedIndex] or center + WALL_OFFSET
					dir -= ADJACENT[dxyIndex] * dist
				end)
			end
			Flowfield._Grid[index] = dir
		end
		return dir
	end
end

-- Returns the path length between pos and the goal. Integer coordinates must be used for pos. If the flowfield is pruned and pos is inside an omitted chunk, nil will be returned.
function Flowfield:GetDistance(pos: Vector2): Vector2
	local Distances = self._Distances
	local index = Distances:_GetCellIndex(forceIntegerCoords(pos))

	if self:_IsCellInChunks(index) then
		return Distances._Grid[index]
	end
end

function Pathfinder:_NewFlowfield(goal: Vector2, startPositions: { Vector2 }): Flowfield
	local Pathfinder = self
	local Regions = self._Regions
	local Walls = self._Walls
	local size = self._Size

	local newPath = {}
	newPath._Goal = goal
	newPath._Chunks = startPositions == nil or {}
	newPath._Pathfinder = Pathfinder
	newPath._Flowfield = Grid.New(size)
	newPath._Distances = Grid.New(size)
	newPath._Distances:SetCell(goal, 0)

	local goalIndex = Walls:_GetCellIndex(goal)
	local goalRegion = Regions._Grid[goalIndex]
	if not goalRegion then
		warnInvalidEndpoint(
			`GenerateFlowfield goal=({goal.X},{goal.Y}) region=nil wall={tostring(Walls._Grid[goalIndex] == true)}`
		)
	end

	if startPositions and goalRegion then
		local visitedRegions = {}

		for _, start in startPositions do
			local startRegion = Regions:GetCell(start)
			if not startRegion then
				local startIndex = Walls:_GetCellIndex(start)
				warnInvalidEndpoint(
					`GenerateFlowfield start=({start.X},{start.Y}) region=nil wall={tostring(Walls._Grid[startIndex] == true)}`
				)
				continue
			end

			if not visitedRegions[startRegion] then
				local startIndex = Walls:_GetCellIndex(start)
				for _, portal in Pathfinder:_GetPortalPath(goalIndex, startIndex) or {} do
					newPath._Chunks[Regions._Grid[portal]] = true
				end
				visitedRegions[startRegion] = true
			end
		end
	end

	setmetatable(newPath, Flowfield)
	return newPath
end

function Pathfinder:_Floodfill(posIndexes: { number }, funct: Function)
	local Walls = self._Walls
	local size = self._Size

	local frontier = Queue.New()
	local visited = Grid.New(size)
	for _, posIndex in posIndexes do
		frontier:Add(posIndex)
		visited._Grid[posIndex] = true
	end

	while frontier:Length() > 0 do
		local currentIndex = frontier:Remove()
		local neighborValid = {}

		Walls:_ForNeighbors(currentIndex, ADJACENT, function(visitedIndex, dxyIndex)
			if visited._Grid[visitedIndex] or Walls._Grid[visitedIndex] then
				return
			end

			if funct(visitedIndex, currentIndex, dxyIndex) then
				frontier:Add(visitedIndex)
				visited._Grid[visitedIndex] = true
				neighborValid[dxyIndex] = true
			end
		end)
	end
end

function Pathfinder:_FloodfillFlowfield(
	posIndexes: { number },
	Path: Flowfield,
	neighbors: { Vector2 }?,
	revisit: boolean?
)
	local Walls = self._Walls
	local Distances = Path._Distances

	local frontier = Queue.New()
	for _, posIndex in posIndexes do
		frontier:Add(posIndex)
	end

	while frontier:Length() > 0 do
		local currentIndex = frontier:Remove()
		local neighborBlocked = {}

		Walls:_ForNeighbors(currentIndex, neighbors or ADJACENT, function(visitedIndex, dxyIndex)
			local visitedDistance = Distances._Grid[visitedIndex]
			if revisit ~= true and visitedDistance then
				return
			end

			if Walls._Grid[visitedIndex] or Path:_IsCellInChunks(visitedIndex) ~= true then
				neighborBlocked[dxyIndex] = true
				return
			end

			local addDistance = dxyIndex <= 4 and 1 or SQRT2
			local newDistance = Distances._Grid[currentIndex] + addDistance
			if visitedDistance and newDistance >= visitedDistance then
				return
			end

			if dxyIndex > 4 and neighborBlocked[dxyIndex - 4] and neighborBlocked[(dxyIndex - 4) % 4 + 1] then
				return
			end

			Distances._Grid[visitedIndex] = newDistance
			frontier:Add(visitedIndex)
		end)
	end
end

function Pathfinder:_FloodChunk(posIndex: number, funct: Function)
	local Walls = self._Walls
	local width = self._ChunkWidth
	local chunkPos = roundVector(Walls:_GetCellPos(posIndex) / width)

	self:_Floodfill({ posIndex }, function(visitedIndex, currentIndex, dxyIndex)
		return roundVector(Walls:_GetCellPos(visitedIndex) / width) == chunkPos
			and funct(visitedIndex, currentIndex, dxyIndex)
	end)
end

function Pathfinder:_SetupPortals(chunkPos: Vector2)
	local Portals = self._Portals
	local Walls = self._Walls
	local chunkSize = self._ChunkSize
	local chunkWidth = self._ChunkWidth

	for i, dxy in ADJACENT do
		local dir = mirrorAbsVector(dxy)
		local diagonal = dir * (chunkSize + 1)
		local center = chunkPos * chunkWidth + dxy * chunkSize

		local lastOpen = nil
		Grid._ForBox(center - diagonal, center + diagonal, function(pos)
			local pos1, pos2 = pos, pos + dxy
			local inBounds = Walls:IsCellInBounds(pos1)
				and Walls:IsCellInBounds(pos2)
				and (pos ~= center - diagonal and pos ~= center + diagonal)

			local wall = Walls:GetCell(pos1) or Walls:GetCell(pos2) or inBounds == false

			if (wall == true) == (lastOpen ~= nil) then
				if wall then
					local center = roundVector((lastOpen + pos - dir) / 2)
					Portals:SetCell(center, { [Portals:_GetCellIndex(center + dxy)] = true })
					Portals:SetCell(center + dxy, { [Portals:_GetCellIndex(center)] = true })
					lastOpen = nil
				else
					lastOpen = pos
				end
			end
		end)
	end
end

function Pathfinder:_ConnectPortals(chunkPos: Vector2)
	local Walls = self._Walls
	local Portals = self._Portals
	local Regions = self._Regions
	local RegionPortals = self._RegionPortals

	local size = self._Size
	local chunkSize = self._ChunkSize
	local chunkWidth = self._ChunkWidth

	local diagonal = ONE_VECTOR * chunkSize
	local center = chunkPos * chunkWidth
	local visited = Grid.New(size)

	Grid._ForBox(center - diagonal, center + diagonal, function(pos)
		local posIndex = Walls:_GetCellIndex(pos)

		if visited._Grid[posIndex] == nil and Walls._Grid[posIndex] == nil and Walls:IsCellInBounds(pos) then
			self._NumRegions += 1
			local regionId = self._NumRegions
			local portals = {}
			RegionPortals[regionId] = {}

			local function visitCell(visitedIndex)
				if not visited._Grid[visitedIndex] then
					visited._Grid[visitedIndex] = true
					Regions._Grid[visitedIndex] = regionId

					if Portals._Grid[visitedIndex] then
						insert(portals, visitedIndex)
						RegionPortals[regionId][visitedIndex] = true
					end
					return true
				end
			end
			visitCell(posIndex)
			self:_FloodChunk(posIndex, visitCell)

			for _, portal in portals do
				local connections = Portals._Grid[portal]
				for _, neighbor in portals do
					if neighbor ~= portal then
						connections[neighbor] = true
					end
				end
			end
		end
	end)
end

function Pathfinder:_GetPortalPath(goalIndex: number, startIndex: number): { number }
	local Walls = self._Walls
	local Portals = self._Portals
	local Regions = self._Regions
	local RegionPortals = self._RegionPortals

	local goal = Walls:_GetCellPos(goalIndex)
	local goalNeighbors = RegionPortals[Regions._Grid[goalIndex]]
	local startNeighbors = RegionPortals[Regions._Grid[startIndex]]
	local goalPortal = Portals._Grid[goalIndex]
	local startPortal = Portals._Grid[startIndex]

	local function enableEndpoints(insert)
		if not goalPortal then
			for portal, _ in goalNeighbors do
				Portals._Grid[portal][goalIndex] = insert
			end
		end
		if not startPortal then
			Portals._Grid[startIndex] = insert and startNeighbors
		end
	end

	local frontier = PriorityQueue.New()
	local distance = { [startIndex] = 0 }
	local parent = {}
	local pathFound = false
	frontier:Add(startIndex, 0)

	enableEndpoints(true)
	while frontier:Length() > 0 do
		local index = frontier:Remove()
		if index == goalIndex then
			pathFound = true
			break
		end

		local pos = Portals:_GetCellPos(index)
		for neighbor, _ in Portals._Grid[index] do
			local neighborPos = Portals:_GetCellPos(neighbor)
			local neighborDist = distance[index] + (pos - neighborPos).Magnitude

			if distance[neighbor] == nil or distance[neighbor] > neighborDist then
				frontier:Add(neighbor, -neighborDist - (goal - neighborPos).Magnitude)
				distance[neighbor] = neighborDist
				parent[neighbor] = index
			end
		end
	end
	enableEndpoints(nil)

	if pathFound then
		local path = {}
		local currentPortal = goalIndex
		while currentPortal do
			insert(path, currentPortal)
			currentPortal = parent[currentPortal]
		end
		return path
	else
		warnInvalidPath()
	end
end

function Flowfield:_IsCellInChunks(posIndex: number): boolean
	local Chunks = self._Chunks
	local Regions = self._Pathfinder._Regions
	return Chunks == true or Chunks[Regions._Grid[posIndex]]
end

FastFlow.EnsureVisualizerReferences()

return FastFlow
