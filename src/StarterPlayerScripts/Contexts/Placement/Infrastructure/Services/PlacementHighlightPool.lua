--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlacementCursorGridService = require(script.Parent.PlacementCursorGridService)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)

type GridCoord = PlacementTypes.GridCoord

local PlacementHighlightPool = {}
PlacementHighlightPool.__index = PlacementHighlightPool

local PREVIEW_CONFIG = PlacementConfig.PREVIEW
local VALID_COLOR = PREVIEW_CONFIG.HighlightColor
local HOVER_COLOR = PREVIEW_CONFIG.HoverColor

local function _GetCoordKey(coord: GridCoord): string
	return `{coord.GridId}:{coord.Row}:{coord.Col}`
end

local function _CreateHighlightPart(parent: Instance, coord: GridCoord, worldPos: Vector3): Part
	local gridSpec = PlacementCursorGridService.GetGridSpec(coord.GridId)
	assert(gridSpec ~= nil, "PlacementHighlightPool: missing grid spec")

	local part = Instance.new("Part")
	part.Name = ("Highlight_%s_%d_%d"):format(coord.GridId, coord.Row, coord.Col)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = PREVIEW_CONFIG.HighlightMaterial
	part.Color = VALID_COLOR
	part.Transparency = PREVIEW_CONFIG.HighlightTransparency
	part.Size = Vector3.new(gridSpec.TileSize, PREVIEW_CONFIG.HighlightThickness, gridSpec.TileSize)
	part.CFrame = CFrame.new(worldPos + Vector3.new(0, PREVIEW_CONFIG.HighlightYOffset, 0))
	part.Parent = parent
	return part
end

function PlacementHighlightPool.new(folder: Folder)
	local self = setmetatable({}, PlacementHighlightPool)
	self._folder = folder
	self._partsByKey = {}
	self._activeCoords = {}
	self._groundWorldPosByKey = {}
	return self
end

function PlacementHighlightPool:ShowValidTiles(coords: { GridCoord })
	for _, part in pairs(self._partsByKey) do
		part:Destroy()
	end
	table.clear(self._partsByKey)
	table.clear(self._activeCoords)

	for _, coord in ipairs(coords) do
		local key = _GetCoordKey(coord)
		local groundWorldPos = self._groundWorldPosByKey[key]
		if groundWorldPos == nil then
			groundWorldPos = PlacementCursorGridService:ResolveGroundWorldPositionForCoord(coord, self._folder)
			self._groundWorldPosByKey[key] = groundWorldPos
		end

		if groundWorldPos == nil then
			continue
		end

		local part = _CreateHighlightPart(self._folder, coord, groundWorldPos)
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
	part.Transparency = if isHovered then PREVIEW_CONFIG.HoverTransparency else PREVIEW_CONFIG.HighlightTransparency
end

function PlacementHighlightPool:HideAll()
	for _, part in pairs(self._partsByKey) do
		part:Destroy()
	end

	table.clear(self._partsByKey)
	table.clear(self._activeCoords)
	table.clear(self._groundWorldPosByKey)
end

function PlacementHighlightPool:Destroy()
	self:HideAll()
end

return PlacementHighlightPool
