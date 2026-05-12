--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetFetcher = require(ReplicatedStorage.Utilities.Assets.AssetFetcher)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local PlacementPlus = require(ReplicatedStorage.Utilities.PlacementPlus)
local MiningConfig = require(ReplicatedStorage.Contexts.Mining.Config.MiningConfig)
local PlacementConfig = require(ReplicatedStorage.Contexts.Placement.Config.PlacementConfig)
local PlacementTypes = require(ReplicatedStorage.Contexts.Placement.Types.PlacementTypes)
local WorldConfig = require(ReplicatedStorage.Contexts.World.Config.WorldConfig)

type GridCoord = PlacementTypes.GridCoord
type FootprintDimensions = PlacementTypes.FootprintDimensions
type FootprintCacheEntry = PlacementTypes.FootprintCacheEntry
type FootprintCacheLookup = PlacementTypes.FootprintCacheLookup
type SpecialTileRequirementMode = PlacementTypes.SpecialTileRequirementMode
type ResolvedFootprint = PlacementTypes.ResolvedFootprint

local PlacementFootprintResolver = {}

local structureRegistry = nil :: any
local structuresFolder = nil :: Folder?

local function _GetCacheKey(structureType: string, rotationQuarterTurns: number): string
	return (`{structureType}:{rotationQuarterTurns}`)
end

local function _CloneCoord(coord: GridCoord): GridCoord
	return table.freeze({
		GridId = coord.GridId,
		Row = coord.Row,
		Col = coord.Col,
	})
end

local function _CreateFootprintDimensions(width: number, depth: number): FootprintDimensions
	return table.freeze({
		Width = width,
		Depth = depth,
	})
end

local function _CreateExtractorFallbackModel(): Model
	local model = Instance.new("Model")
	model.Name = MiningConfig.EXTRACTOR_STRUCTURE_TYPE

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = false
	base.Size = Vector3.new(5, 1, 5)
	base.Parent = model

	local core = Instance.new("Part")
	core.Name = "ExtractorCore"
	core.Anchored = true
	core.CanCollide = false
	core.Size = Vector3.new(2, 4, 2)
	core.Position = Vector3.new(0, 2.5, 0)
	core.Parent = model

	model.PrimaryPart = base
	return model
end

local function _EnsureStructureRegistry()
	if structureRegistry ~= nil or structuresFolder ~= nil then
		return
	end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder == nil then
		return
	end

	local folder = assetsFolder:FindFirstChild("Structures")
	if folder == nil or not folder:IsA("Folder") then
		return
	end

	structuresFolder = folder
	structureRegistry = AssetFetcher.CreateStructureRegistry(folder)
end

local function _ResolveStructureModel(structureType: string): Model?
	_EnsureStructureRegistry()

	if structureRegistry ~= nil then
		local model = structureRegistry:GetStructureModel(structureType)
		if model ~= nil then
			return model
		end
	end

	if structureType == MiningConfig.EXTRACTOR_STRUCTURE_TYPE then
		return _CreateExtractorFallbackModel()
	end

	return nil
end

local function _ResolveBaseFootprintFromModel(structureType: string): FootprintDimensions
	local model = _ResolveStructureModel(structureType)
	if model == nil then
		return _CreateFootprintDimensions(1, 1)
	end

	local _, boundsSize = ModelPlus.GetBounds(model)
	local footprint = PlacementPlus.BuildFootprintFromBounds(boundsSize, nil)
	model:Destroy()

	return _CreateFootprintDimensions(
		math.max(1, math.ceil(footprint.Size.X / WorldConfig.TILE_SIZE)),
		math.max(1, math.ceil(footprint.Size.Z / WorldConfig.TILE_SIZE))
	)
end

local function _ResolveBaseFootprintDimensions(structureType: string): FootprintDimensions
	local profile = PlacementConfig.STRUCTURE_PLACEMENT_PROFILES[structureType]
	local footprint = profile and profile.Footprint or nil
	if footprint ~= nil and type(footprint.Width) == "number" and type(footprint.Depth) == "number" then
		return _CreateFootprintDimensions(
			math.max(1, math.floor(footprint.Width)),
			math.max(1, math.floor(footprint.Depth))
		)
	end

	return _ResolveBaseFootprintFromModel(structureType)
end

local function _ResolveSpecialTileRequirementMode(structureType: string): SpecialTileRequirementMode
	local profile = PlacementConfig.STRUCTURE_PLACEMENT_PROFILES[structureType]
	local mode = profile and profile.SpecialTileRequirementMode or nil
	if mode == "AllTiles" then
		return mode
	end

	return PlacementConfig.DEFAULT_SPECIAL_TILE_REQUIREMENT_MODE
end

local function _BuildCacheEntriesForStructureType(structureType: string): { FootprintCacheEntry }
	local baseDimensions = _ResolveBaseFootprintDimensions(structureType)
	local specialTileRequirementMode = _ResolveSpecialTileRequirementMode(structureType)
	local entries = table.create(4)

	for rotationQuarterTurns = 0, 3 do
		local widthTiles = baseDimensions.Width
		local depthTiles = baseDimensions.Depth
		if rotationQuarterTurns % 2 == 1 then
			widthTiles = baseDimensions.Depth
			depthTiles = baseDimensions.Width
		end

		table.insert(entries, table.freeze({
			StructureType = structureType,
			RotationQuarterTurns = rotationQuarterTurns,
			WidthTiles = widthTiles,
			DepthTiles = depthTiles,
			SpecialTileRequirementMode = specialTileRequirementMode,
		}))
	end

	return entries
end

function PlacementFootprintResolver.NormalizeRotationQuarterTurns(rotationQuarterTurns: number?): number
	local turns = if type(rotationQuarterTurns) == "number" then math.floor(rotationQuarterTurns) else 0
	turns %= 4
	if turns < 0 then
		turns += 4
	end
	return turns
end

function PlacementFootprintResolver.BuildLookup(entries: { FootprintCacheEntry }?): FootprintCacheLookup
	local lookup = {} :: FootprintCacheLookup
	if type(entries) ~= "table" then
		return lookup
	end

	for _, entry in ipairs(entries) do
		lookup[_GetCacheKey(entry.StructureType, entry.RotationQuarterTurns)] = entry
	end

	return lookup
end

function PlacementFootprintResolver.ResolveCacheEntry(
	footprintCacheLookup: FootprintCacheLookup,
	structureType: string,
	rotationQuarterTurns: number?
): FootprintCacheEntry?
	local normalizedTurns = PlacementFootprintResolver.NormalizeRotationQuarterTurns(rotationQuarterTurns)
	return footprintCacheLookup[_GetCacheKey(structureType, normalizedTurns)]
end

function PlacementFootprintResolver.ResolveDimensions(
	footprintCacheLookup: FootprintCacheLookup,
	structureType: string,
	rotationQuarterTurns: number?
): FootprintDimensions?
	local entry = PlacementFootprintResolver.ResolveCacheEntry(
		footprintCacheLookup,
		structureType,
		rotationQuarterTurns
	)
	if entry == nil then
		return nil
	end

	return _CreateFootprintDimensions(entry.WidthTiles, entry.DepthTiles)
end

function PlacementFootprintResolver.BuildOccupiedCoords(
	anchorCoord: GridCoord,
	widthTiles: number,
	depthTiles: number
): { GridCoord }
	local occupiedCoords = table.create(widthTiles * depthTiles)
	for rowOffset = 0, depthTiles - 1 do
		for colOffset = 0, widthTiles - 1 do
			table.insert(occupiedCoords, table.freeze({
				GridId = anchorCoord.GridId,
				Row = anchorCoord.Row + rowOffset,
				Col = anchorCoord.Col + colOffset,
			}))
		end
	end
	return table.freeze(occupiedCoords)
end

function PlacementFootprintResolver.Resolve(
	footprintCacheLookup: FootprintCacheLookup,
	structureType: string,
	anchorCoord: GridCoord,
	rotationQuarterTurns: number?
): ResolvedFootprint?
	local entry = PlacementFootprintResolver.ResolveCacheEntry(
		footprintCacheLookup,
		structureType,
		rotationQuarterTurns
	)
	if entry == nil then
		return nil
	end

	return table.freeze({
		AnchorCoord = _CloneCoord(anchorCoord),
		RotationQuarterTurns = entry.RotationQuarterTurns,
		WidthTiles = entry.WidthTiles,
		DepthTiles = entry.DepthTiles,
		SpecialTileRequirementMode = entry.SpecialTileRequirementMode,
		OccupiedCoords = PlacementFootprintResolver.BuildOccupiedCoords(
			anchorCoord,
			entry.WidthTiles,
			entry.DepthTiles
		),
	})
end

function PlacementFootprintResolver.BuildCacheEntriesForConfiguredStructures(): { FootprintCacheEntry }
	local structureTypes = {}
	for structureType in PlacementConfig.STRUCTURE_PLACEMENT_COSTS do
		table.insert(structureTypes, structureType)
	end

	table.sort(structureTypes)

	local entries = {}
	for _, structureType in ipairs(structureTypes) do
		for _, entry in ipairs(_BuildCacheEntriesForStructureType(structureType)) do
			table.insert(entries, entry)
		end
	end

	return table.freeze(entries)
end

return table.freeze(PlacementFootprintResolver)
