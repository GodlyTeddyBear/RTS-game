--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local SharedAtoms = require(ReplicatedStorage.Contexts.World.Sync.SharedAtoms)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type Tile = WorldTypes.Tile
type GridSpec = WorldTypes.GridSpec

local WorldSyncService = {}
WorldSyncService.__index = WorldSyncService

local PROFILE_NAME = "WorldSyncService"
local SYNC_SERVICE_PROFILING_ENABLED = DebugConfig.SYNC_SERVICE_PROFILING

local function _FreezeGridSpecs(gridSpecs: { GridSpec }): { [number]: any }
	local payload = table.create(#gridSpecs)
	for index, spec in ipairs(gridSpecs) do
		local cframe = spec.GridCFrame
		payload[index] = table.freeze({
			GridId = spec.GridId,
			OriginX = cframe.Position.X,
			OriginY = cframe.Position.Y,
			OriginZ = cframe.Position.Z,
			RightX = cframe.RightVector.X,
			RightY = cframe.RightVector.Y,
			RightZ = cframe.RightVector.Z,
			UpX = cframe.UpVector.X,
			UpY = cframe.UpVector.Y,
			UpZ = cframe.UpVector.Z,
			LookX = cframe.LookVector.X,
			LookY = cframe.LookVector.Y,
			LookZ = cframe.LookVector.Z,
			GridSizeX = spec.GridSize.X,
			GridSizeY = spec.GridSize.Y,
			GridSizeZ = spec.GridSize.Z,
			TileSize = spec.TileSize,
			GridRows = spec.GridRows,
			GridCols = spec.GridCols,
			LaneRow = spec.LaneRow,
		})
	end
	return table.freeze(payload)
end

local function _FreezeTiles(tiles: { Tile }): { [number]: any }
	local payload = table.create(#tiles)
	for index, tile in ipairs(tiles) do
		payload[index] = table.freeze({
			GridId = tile.Coord.GridId,
			Row = tile.Coord.Row,
			Col = tile.Coord.Col,
			WorldPosX = tile.WorldPos.X,
			WorldPosY = tile.WorldPos.Y,
			WorldPosZ = tile.WorldPos.Z,
			Zone = tile.Zone,
			ResourceType = tile.ResourceType,
			IsPlacementProhibited = tile.IsPlacementProhibited,
		})
	end
	return table.freeze(payload)
end

local function _FreezeOccupiedCoords(coords: { GridSpec | any }): { [number]: any }
	local payload = table.create(#coords)
	for index, coord in ipairs(coords) do
		payload[index] = table.freeze({
			GridId = coord.GridId,
			Row = coord.Row,
			Col = coord.Col,
		})
	end
	return table.freeze(payload)
end

function WorldSyncService.new()
	local self = setmetatable({}, WorldSyncService)
	self.Atom = nil :: any
	self.Syncer = nil :: any
	self.Cleanup = nil :: (() -> ())?
	self.BlinkServer = nil :: any
	return self
end

function WorldSyncService:Init(registry: any, _name: string)
	self.BlinkServer = registry:Get("BlinkServer")
	self.Atom = SharedAtoms.CreateServerAtom()
	self.Syncer = CharmSync.server({
		atoms = { WorldGrid = self.Atom },
		interval = 0.1,
		preserveHistory = false,
		autoSerialize = false,
	})

	self.Cleanup = self.Syncer:connect(function(player: Player, payload: any)
		self.BlinkServer.SyncWorldGrid.Fire(player, payload)
	end)
end

function WorldSyncService:HydratePlayer(player: Player)
	DebugPlus.profile(("%s:HydratePlayer"):format(PROFILE_NAME), function()
		self.Syncer:hydrate(player)
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

function WorldSyncService:SetSnapshot(gridSpecs: { GridSpec }, tiles: { Tile }, occupiedCoords: { any }?)
	DebugPlus.profile(("%s:SetSnapshot"):format(PROFILE_NAME), function()
		local frozenGridSpecs = _FreezeGridSpecs(gridSpecs)
		local frozenTiles = _FreezeTiles(tiles)
		local frozenOccupiedCoords = _FreezeOccupiedCoords(occupiedCoords or {})

		self.Atom(function(current)
			return {
				StaticVersion = current.StaticVersion + 1,
				OccupancyVersion = current.OccupancyVersion + 1,
				GridSpecs = frozenGridSpecs,
				Tiles = frozenTiles,
				OccupiedCoords = frozenOccupiedCoords,
			}
		end)
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

function WorldSyncService:SetOccupancySnapshot(occupiedCoords: { any })
	DebugPlus.profile(("%s:SetOccupancySnapshot"):format(PROFILE_NAME), function()
		local frozenOccupiedCoords = _FreezeOccupiedCoords(occupiedCoords)

		self.Atom(function(current)
			return {
				StaticVersion = current.StaticVersion,
				OccupancyVersion = current.OccupancyVersion + 1,
				GridSpecs = current.GridSpecs,
				Tiles = current.Tiles,
				OccupiedCoords = frozenOccupiedCoords,
			}
		end)
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

function WorldSyncService:Destroy()
	DebugPlus.profile(("%s:Destroy"):format(PROFILE_NAME), function()
		if self.Cleanup then
			self.Cleanup()
		end
	end, SYNC_SERVICE_PROFILING_ENABLED)
end

return WorldSyncService
