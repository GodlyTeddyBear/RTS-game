--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharmSync = require(ReplicatedStorage.Packages["Charm-sync"])
local SharedAtoms = require(ReplicatedStorage.Contexts.World.Sync.SharedAtoms)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type Tile = WorldTypes.Tile
type GridSpec = WorldTypes.GridSpec

local WorldSyncService = {}
WorldSyncService.__index = WorldSyncService

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
			Occupied = tile.Occupied,
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
	self.Syncer:hydrate(player)
end

function WorldSyncService:SetSnapshot(gridSpecs: { GridSpec }, tiles: { Tile })
	local frozenGridSpecs = _FreezeGridSpecs(gridSpecs)
	local frozenTiles = _FreezeTiles(tiles)

	self.Atom(function()
		return {
			GridSpecs = frozenGridSpecs,
			Tiles = frozenTiles,
		}
	end)
end

function WorldSyncService:Destroy()
	if self.Cleanup then
		self.Cleanup()
	end
end

return WorldSyncService
