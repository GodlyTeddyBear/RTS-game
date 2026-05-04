local GridStatic = {}
local Grid = {}
Grid.__index = Grid
export type Grid = typeof(setmetatable({}, Grid))

local floor = math.floor
local abs = math.abs
local clone = table.clone
local create = table.create
local newVector = Vector2.new

-- Returns a new grid object where the maximum coordinate possible is maxCoordinate and every cell is instantiated as fill.
function GridStatic.New(maxCoordinate: number, fill: any?): Grid
	local newGrid = {}
	newGrid._Size = maxCoordinate
	newGrid._Width = maxCoordinate * 2 + 1
	newGrid._Grid = {}

	if fill then
		local maxIndex = newGrid._Width * newGrid._Width
		newGrid._Grid = create(maxIndex, fill)
		newGrid._Grid[maxIndex] = nil
		newGrid._Grid[0] = fill
	end

	setmetatable(newGrid, Grid)
	return newGrid
end

-- Sets the cell at pos to value. Integer coordinates must be used for pos. No warning will be thrown for out-of-bounds positions.
function Grid:SetCell(pos: Vector2, value: any)
	self._Grid[self:_GetCellIndex(pos)] = value
end

-- Returns the value of cell at pos. Integer coordinates must be used for pos. No warning will be thrown for out-of-bounds positions.
function Grid:GetCell(pos: Vector2): any
	return self._Grid[self:_GetCellIndex(pos)]
end

-- Returns whether or not pos is in bounds
function Grid:IsCellInBounds(pos: Vector2): boolean
	return abs(pos.X) <= self._Size and abs(pos.Y) <= self._Size
end

-- Sets every cell in the grid to nil
function Grid:ClearGrid()
	self._Grid = {}
end

function Grid:_GetCellIndex(pos: Vector2): number
	return (pos.X + self._Size) * self._Width + (pos.Y + self._Size)
end

function Grid:_GetCellPos(index: number): Vector2
	local x = floor(index / self._Width)
	local y = index - x * self._Width
	return newVector(x - self._Size, y - self._Size)
end

function Grid:_ForNeighbors(index: number, neighbors: table, funct: Function)
	local WIDTH = self._Width
	for i, dxy in neighbors do
		funct(index + dxy.X * WIDTH + dxy.Y, i)
	end
end

function GridStatic._ForBox(corner1: Vector2, corner2: Vector2, funct: Function)
	for x = corner1.X, corner2.X, 1 do
		for y = corner1.Y, corner2.Y, 1 do
			funct(newVector(x, y))
		end
	end
end

return GridStatic
