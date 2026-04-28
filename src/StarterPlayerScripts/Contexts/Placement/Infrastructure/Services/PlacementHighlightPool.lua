--!strict

--[=[
    @class PlacementHighlightPool
    Owns the client-side highlight parts that mark valid and hovered placement tiles.

    The placement cursor controller uses this pool to create, recolor, and destroy the
    tile overlays that visualize placement eligibility. It does not own grid math or
    placement validation.
    @client
]=]

local PlacementCursorGridService = require(script.Parent.PlacementCursorGridService)
local PlacementGridRuntime = require(script.Parent.PlacementGridRuntime)

type GridCoord = {
	row: number,
	col: number,
}

local PlacementHighlightPool = {}
PlacementHighlightPool.__index = PlacementHighlightPool

local VALID_COLOR = Color3.fromRGB(0, 200, 100)
local HOVER_COLOR = Color3.fromRGB(255, 230, 0)

-- Builds a stable key for a highlight tile so the pool can track parts by coordinate.
local function _GetCoordKey(row: number, col: number): string
	return ("%d_%d"):format(row, col)
end

-- Creates the highlight part for a single grid coordinate and positions it above the tile.
local function _CreateHighlightPart(parent: Instance, coord: GridCoord): Part
	local gridSpec = PlacementGridRuntime.GetGridSpec()
	local part = Instance.new("Part")
	part.Name = ("Highlight_%d_%d"):format(coord.row, coord.col)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = VALID_COLOR
	part.Transparency = 0.5
	part.Size = Vector3.new(gridSpec.tileSize, 0.05, gridSpec.tileSize)
	part.CFrame = CFrame.new(PlacementCursorGridService.CoordToWorld(coord.row, coord.col) + Vector3.new(0, 0.025, 0))
	part.Parent = parent
	return part
end

--[=[
    Creates a new highlight pool bound to the provided folder.
    @within PlacementHighlightPool
    @param folder Folder -- Parent folder for spawned highlight parts.
    @return PlacementHighlightPool -- The new highlight pool.
]=]
function PlacementHighlightPool.new(folder: Folder)
	local self = setmetatable({}, PlacementHighlightPool)
	self._folder = folder
	self._partsByKey = {}
	self._activeCoords = {}
	return self
end

--[=[
    Shows highlight parts for every valid coordinate in the list.
    @within PlacementHighlightPool
    @param coords { GridCoord } -- Valid placement coordinates to display.
]=]
function PlacementHighlightPool:ShowValidTiles(coords: { GridCoord })
	-- Clear old highlights before recreating them for the new valid tile set.
	self:HideAll()

	for _, coord in ipairs(coords) do
		local key = _GetCoordKey(coord.row, coord.col)
		local part = _CreateHighlightPart(self._folder, coord)
		self._partsByKey[key] = part
		self._activeCoords[key] = coord
	end
end

--[=[
    Updates the hover tint for a specific tile.
    @within PlacementHighlightPool
    @param row number -- Hovered grid row.
    @param col number -- Hovered grid column.
    @param isHovered boolean -- Whether the tile is currently hovered.
]=]
function PlacementHighlightPool:SetHovered(row: number, col: number, isHovered: boolean)
	local key = _GetCoordKey(row, col)
	local part = self._partsByKey[key]
	if part == nil then
		return
	end

	part.Color = if isHovered then HOVER_COLOR else VALID_COLOR
	part.Transparency = if isHovered then 0.35 else 0.5
end

--[=[
    Destroys every highlight part and clears the pool.
    @within PlacementHighlightPool
]=]
function PlacementHighlightPool:HideAll()
	for _, part in pairs(self._partsByKey) do
		part:Destroy()
	end

	table.clear(self._partsByKey)
	table.clear(self._activeCoords)
end

--[=[
    Destroys the pool and all active highlight parts.
    @within PlacementHighlightPool
]=]
function PlacementHighlightPool:Destroy()
	self:HideAll()
end

return PlacementHighlightPool
