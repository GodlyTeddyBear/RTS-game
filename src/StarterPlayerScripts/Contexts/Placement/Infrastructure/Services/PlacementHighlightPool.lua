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
local INVALID_HOVER_COLOR = PREVIEW_CONFIG.InvalidHoverColor

local function _GetCoordKey(coord: GridCoord): string
	return `{coord.GridId}:{coord.Row}:{coord.Col}`
end

local function _CreateHighlightPart(parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = "PlacementHighlight"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = PREVIEW_CONFIG.HighlightMaterial
	part.Transparency = PREVIEW_CONFIG.HighlightTransparency
	part.Parent = parent
	return part
end

local function _HidePart(part: Part)
	part.Parent = nil
end

function PlacementHighlightPool.new(folder: Folder)
	local self = setmetatable({}, PlacementHighlightPool)
	self._folder = folder
	self._groundWorldPosByKey = {}
	self._validPool = {}
	self._hoverPool = {}
	self._validPartsByKey = {}
	self._hoverPartsByKey = {}
	self._validActiveCount = 0
	self._hoverActiveCount = 0
	return self
end

function PlacementHighlightPool:_AcquirePart(poolName: "_validPool" | "_hoverPool", activeIndex: number): Part
	local pool = self[poolName]
	local part = pool[activeIndex]
	if part == nil then
		part = _CreateHighlightPart(self._folder)
		pool[activeIndex] = part
	else
		part.Parent = self._folder
	end
	return part
end

function PlacementHighlightPool:_ReleaseUnused(poolName: "_validPool" | "_hoverPool", usedCount: number)
	local pool = self[poolName]
	for index = usedCount + 1, #pool do
		_HidePart(pool[index])
	end
end

function PlacementHighlightPool:_ResolveGroundWorldPosition(coord: GridCoord): Vector3?
	local key = _GetCoordKey(coord)
	local groundWorldPos = self._groundWorldPosByKey[key]
	if groundWorldPos == nil then
		groundWorldPos = PlacementCursorGridService:ResolveGroundWorldPositionForCoord(coord, self._folder)
		self._groundWorldPosByKey[key] = groundWorldPos
	end
	return groundWorldPos
end

function PlacementHighlightPool:_ConfigurePart(part: Part, coord: GridCoord, worldPos: Vector3, color: Color3, transparency: number, namePrefix: string)
	local gridSpec = PlacementCursorGridService.GetGridSpec(coord.GridId)
	assert(gridSpec ~= nil, "PlacementHighlightPool: missing grid spec")

	part.Name = (`{namePrefix}_{coord.GridId}_{coord.Row}_{coord.Col}`)
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(gridSpec.TileSize, PREVIEW_CONFIG.HighlightThickness, gridSpec.TileSize)
	part.CFrame = CFrame.new(worldPos + Vector3.new(0, PREVIEW_CONFIG.HighlightYOffset, 0))
	part.Parent = self._folder
end

function PlacementHighlightPool:ShowValidTiles(coords: { GridCoord })
	table.clear(self._validPartsByKey)

	local activeCount = 0
	for _, coord in ipairs(coords) do
		local groundWorldPos = self:_ResolveGroundWorldPosition(coord)
		if groundWorldPos == nil then
			continue
		end

		activeCount += 1
		local key = _GetCoordKey(coord)
		local part = self:_AcquirePart("_validPool", activeCount)
		self:_ConfigurePart(part, coord, groundWorldPos, VALID_COLOR, PREVIEW_CONFIG.HighlightTransparency, "Highlight")
		self._validPartsByKey[key] = part
	end

	self._validActiveCount = activeCount
	self:_ReleaseUnused("_validPool", activeCount)
end

function PlacementHighlightPool:SetHovered(coord: GridCoord, isHovered: boolean)
	local key = _GetCoordKey(coord)
	local part = self._validPartsByKey[key]
	if part == nil then
		return
	end

	part.Color = if isHovered then HOVER_COLOR else VALID_COLOR
	part.Transparency = if isHovered then PREVIEW_CONFIG.HoverTransparency else PREVIEW_CONFIG.HighlightTransparency
end

function PlacementHighlightPool:ShowHoveredFootprint(coords: { GridCoord }, isValid: boolean)
	table.clear(self._hoverPartsByKey)

	local hoverColor = if isValid then HOVER_COLOR else INVALID_HOVER_COLOR
	local activeCount = 0
	for _, coord in ipairs(coords) do
		local groundWorldPos = self:_ResolveGroundWorldPosition(coord)
		if groundWorldPos == nil then
			continue
		end

		activeCount += 1
		local key = _GetCoordKey(coord)
		local part = self:_AcquirePart("_hoverPool", activeCount)
		self:_ConfigurePart(part, coord, groundWorldPos, hoverColor, PREVIEW_CONFIG.HoverTransparency, "Hover")
		self._hoverPartsByKey[key] = part
	end

	self._hoverActiveCount = activeCount
	self:_ReleaseUnused("_hoverPool", activeCount)
end

function PlacementHighlightPool:HideAll()
	table.clear(self._validPartsByKey)
	table.clear(self._hoverPartsByKey)
	table.clear(self._groundWorldPosByKey)
	self._validActiveCount = 0
	self._hoverActiveCount = 0
	self:_ReleaseUnused("_validPool", 0)
	self:_ReleaseUnused("_hoverPool", 0)
end

function PlacementHighlightPool:Destroy()
	for _, part in ipairs(self._validPool) do
		part:Destroy()
	end
	for _, part in ipairs(self._hoverPool) do
		part:Destroy()
	end

	table.clear(self._validPool)
	table.clear(self._hoverPool)
	table.clear(self._validPartsByKey)
	table.clear(self._hoverPartsByKey)
	table.clear(self._groundWorldPosByKey)
end

return PlacementHighlightPool
