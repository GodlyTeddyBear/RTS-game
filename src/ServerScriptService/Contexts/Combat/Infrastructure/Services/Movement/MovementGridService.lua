--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local CombatMovementConfig = require(ReplicatedStorage.Contexts.Combat.Config.CombatMovementConfig)
local FastFlow = require(ServerStorage.Utilities.FastFlow)
local FastFlowHelper = require(ServerStorage.Utilities.FastFlowHelper)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridSpec = WorldTypes.GridSpec
type Tile = WorldTypes.Tile

local MovementGridService = {}
MovementGridService.__index = MovementGridService

local function getGridSubdivisions(): number
	local gridConfig = CombatMovementConfig.FASTFLOW_GRID
	local configured = if gridConfig ~= nil then gridConfig.Subdivisions else nil
	return if type(configured) == "number" then math.max(1, math.floor(configured)) else 1
end

local function getGridOriginWorld(spec: GridSpec): Vector3
	local midCol = math.floor((spec.GridCols + 1) * 0.5)
	local midRow = math.floor((spec.GridRows + 1) * 0.5)
	local localX = -spec.GridSize.X * 0.5 + spec.TileSize * 0.5 + (midCol - 1) * spec.TileSize
	local localZ = -spec.GridSize.Z * 0.5 + spec.TileSize * 0.5 + (midRow - 1) * spec.TileSize
	return spec.GridCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

local function buildFlowGridMapping(spec: GridSpec, subdivisions: number): FastFlowHelper.TFlowGridMapping
	local midCol = math.floor((spec.GridCols + 1) * 0.5)
	local midRow = math.floor((spec.GridRows + 1) * 0.5)
	local minColCell = (-(midCol - 1)) * subdivisions
	local maxColCell = (spec.GridCols - midCol) * subdivisions
	local minRowCell = (-(midRow - 1)) * subdivisions
	local maxRowCell = (spec.GridRows - midRow) * subdivisions
	local subCellStart = -math.floor((subdivisions - 1) * 0.5)
	local subCellEnd = subCellStart + subdivisions - 1
	return {
		OriginWorld = getGridOriginWorld(spec),
		CellWidthStuds = spec.TileSize / subdivisions,
		GridHalfSize = math.max(
			math.abs(minColCell + subCellStart),
			math.abs(maxColCell + subCellEnd),
			math.abs(minRowCell + subCellStart),
			math.abs(maxRowCell + subCellEnd)
		),
	}
end

local function isTileBlockedForFlow(tile: Tile): boolean
	return tile.Zone == "blocked" or tile.IsPlacementProhibited == true
end

local function buildWallsFromTiles(spec: GridSpec, tiles: { Tile }): (any, FastFlowHelper.TFlowGridMapping)
	local subdivisions = getGridSubdivisions()
	local mapping = buildFlowGridMapping(spec, subdivisions)
	local walls = FastFlow.Grid.New(mapping.GridHalfSize, true)
	local subCellStart = -math.floor((subdivisions - 1) * 0.5)
	local subCellEnd = subCellStart + subdivisions - 1

	for _, tile in ipairs(tiles) do
		if tile.Coord.GridId ~= spec.GridId then
			continue
		end

		local centerCell = FastFlowHelper.WorldXZToGridCell(tile.WorldPos, mapping)
		local isBlocked = isTileBlockedForFlow(tile)
		for dx = subCellStart, subCellEnd do
			for dy = subCellStart, subCellEnd do
				local cell = Vector2.new(centerCell.X + dx, centerCell.Y + dy)
				if walls:IsCellInBounds(cell) then
					walls:SetCell(cell, if isBlocked then true else nil)
				end
			end
		end
	end

	return walls, mapping
end

function MovementGridService.new()
	local self = setmetatable({}, MovementGridService)
	self._gridRevision = 0
	self._isFastFlowConfigured = false
	self._pathfinder = nil
	self._mapping = nil
	return self
end

function MovementGridService:EnsureConfigured(worldContext: any): (boolean, number)
	if self._isFastFlowConfigured then
		return true, self._gridRevision
	end

	if worldContext == nil then
		return false, self._gridRevision
	end

	local gridSpecsResult = worldContext:GetGridSpecList()
	local tilesResult = worldContext:GetAllTilesView()
	if not gridSpecsResult.success or not tilesResult.success then
		return false, self._gridRevision
	end

	local selectedGrid = gridSpecsResult.value[1]
	if selectedGrid == nil then
		return false, self._gridRevision
	end

	local walls, mapping = buildWallsFromTiles(selectedGrid, tilesResult.value)
	self._pathfinder = FastFlowHelper.CreatePathfinderFromWalls(walls)
	self._mapping = mapping
	self._gridRevision += 1
	self._isFastFlowConfigured = true

	return true, self._gridRevision
end

function MovementGridService:GetRuntime(): (any?, FastFlowHelper.TFlowGridMapping?)
	return self._pathfinder, self._mapping
end

function MovementGridService:BuildWallGridSnapshot(): ({ boolean }, number, number)
	local pathfinder = self._pathfinder
	local mapping = self._mapping
	local wallGrid = {}
	if pathfinder == nil or mapping == nil then
		return wallGrid, 0, 0
	end

	local walls = pathfinder._Walls
	local wallGridWidth = if type(walls) == "table" and type(walls._Width) == "number"
		then walls._Width
		else mapping.GridHalfSize * 2 + 1
	local wallGridCellCount = wallGridWidth * wallGridWidth
	for index = 1, wallGridCellCount do
		wallGrid[index] = false
	end

	if walls and type(walls._Grid) == "table" then
		for index, value in walls._Grid do
			if value then
				wallGrid[index + 1] = true
			end
		end
	end

	local wallGridHalfSize = if type(walls) == "table" and type(walls._Size) == "number" then walls._Size else 0
	return wallGrid, wallGridHalfSize, wallGridWidth
end

function MovementGridService:Reset()
	self._isFastFlowConfigured = false
	self._pathfinder = nil
	self._mapping = nil
end

return MovementGridService
