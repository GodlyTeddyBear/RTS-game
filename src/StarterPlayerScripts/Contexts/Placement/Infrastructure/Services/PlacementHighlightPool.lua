--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementCursorGridService = require(script.Parent.PlacementCursorGridService)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type GridCoord = PlacementTypes.GridCoord

local PlacementHighlightPool = {}
PlacementHighlightPool.__index = PlacementHighlightPool

local VALID_COLOR = Color3.fromRGB(0, 200, 100)
local HOVER_COLOR = Color3.fromRGB(255, 230, 0)

local function _GetCoordKey(coord: GridCoord): string
	return (`{coord.GridId}:{coord.Row}:{coord.Col}`)
end

local function _CreateHighlightPart(parent: Instance, coord: GridCoord): Part
	local gridSpec = PlacementCursorGridService.GetGridSpec(coord.GridId)
	assert(gridSpec ~= nil, "PlacementHighlightPool: missing grid spec")

	local part = Instance.new("Part")
	part.Name = ("Highlight_%s_%d_%d"):format(coord.GridId, coord.Row, coord.Col)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = VALID_COLOR
	part.Transparency = 0.5
	part.Size = Vector3.new(gridSpec.TileSize, 0.05, gridSpec.TileSize)
	part.CFrame = CFrame.new(PlacementCursorGridService.CoordToWorld(coord) + Vector3.new(0, 0.025, 0))
	part.Parent = parent
	return part
end

function PlacementHighlightPool.new(folder: Folder)
	local self = setmetatable({}, PlacementHighlightPool)
	self._folder = folder
	self._partsByKey = {}
	self._activeCoords = {}
	return self
end

function PlacementHighlightPool:ShowValidTiles(coords: { GridCoord })
	self:HideAll()

	for _, coord in ipairs(coords) do
		local key = _GetCoordKey(coord)
		local part = _CreateHighlightPart(self._folder, coord)
		self._partsByKey[key] = part
		self._activeCoords[key] = coord
	end
end

function PlacementHighlightPool:SetHovered(coord: GridCoord, isHovered: boolean)
	local key = _GetCoordKey(coord)
	local part = self._partsByKey[key]
	if part == nil then
		return
	end

	part.Color = if isHovered then HOVER_COLOR else VALID_COLOR
	part.Transparency = if isHovered then 0.35 else 0.5
end

function PlacementHighlightPool:HideAll()
	for _, part in pairs(self._partsByKey) do
		part:Destroy()
	end

	table.clear(self._partsByKey)
	table.clear(self._activeCoords)
end

function PlacementHighlightPool:Destroy()
	self:HideAll()
end

return PlacementHighlightPool
