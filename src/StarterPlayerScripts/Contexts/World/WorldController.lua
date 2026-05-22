--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local WorldGridSyncClient = require(script.Parent.Infrastructure.Persistence.WorldGridSyncClient)

local WorldController = Knit.CreateController({
	Name = "WorldController",
})

local warnedNoSyncData = false

local function _GetCoordKey(gridId: string, row: number, col: number): string
	return (`{gridId}:{row}:{col}`)
end

local function _BuildSpecCFrame(spec: any): CFrame?
	if spec == nil then
		return nil
	end

	if type(spec.OriginX) ~= "number" or type(spec.OriginY) ~= "number" or type(spec.OriginZ) ~= "number" then
		return nil
	end

	if type(spec.RightX) ~= "number" or type(spec.RightY) ~= "number" or type(spec.RightZ) ~= "number" then
		return nil
	end

	if type(spec.UpX) ~= "number" or type(spec.UpY) ~= "number" or type(spec.UpZ) ~= "number" then
		return nil
	end

	local origin = Vector3.new(spec.OriginX, spec.OriginY, spec.OriginZ)
	local right = Vector3.new(spec.RightX, spec.RightY, spec.RightZ)
	local up = Vector3.new(spec.UpX, spec.UpY, spec.UpZ)
	local look = Vector3.new(spec.LookX or 0, spec.LookY or 0, spec.LookZ or -1)
	return CFrame.fromMatrix(origin, right, up, -look)
end

function WorldController:KnitInit()
	self._syncClient = WorldGridSyncClient.new()
	self._indexedStaticVersion = -1
	self._indexedOccupancyVersion = -1
	self._gridSpecsList = {}
	self._gridSpecById = {}
	self._tileWorldPosByCoordKey = {}
	self._tileDescriptorByCoordKey = {}
	self._occupiedCoordKeySet = {}
end

function WorldController:KnitStart()
	self._syncClient:Start()
end

function WorldController:GetAtom()
	return self._syncClient:GetAtom()
end

function WorldController:_EnsureIndexes()
	local state = self._syncClient:GetAtom()()
	if type(state) ~= "table" then
		return
	end

	local staticVersion = if type(state.StaticVersion) == "number" then state.StaticVersion else 0
	if self._indexedStaticVersion ~= staticVersion then
		local specs = if type(state.GridSpecs) == "table" then state.GridSpecs else {}
		local tiles = if type(state.Tiles) == "table" then state.Tiles else {}
		local gridSpecById = {}
		local tileWorldPosByCoordKey = {}
		local tileDescriptorByCoordKey = {}

		for _, spec in ipairs(specs) do
			if type(spec) == "table" and type(spec.GridId) == "string" then
				gridSpecById[spec.GridId] = spec
			end
		end

		for _, tile in ipairs(tiles) do
			if type(tile) ~= "table" then
				continue
			end

			local gridId = tile.GridId
			local row = tile.Row
			local col = tile.Col
			if type(gridId) ~= "string" or type(row) ~= "number" or type(col) ~= "number" then
				continue
			end

			local coordKey = _GetCoordKey(gridId, row, col)
			tileWorldPosByCoordKey[coordKey] = Vector3.new(tile.WorldPosX or 0, tile.WorldPosY or 0, tile.WorldPosZ or 0)
			tileDescriptorByCoordKey[coordKey] = table.freeze({
				Zone = tile.Zone,
				ResourceType = tile.ResourceType,
				IsPlacementProhibited = tile.IsPlacementProhibited == true,
			})
		end

		self._gridSpecsList = specs
		self._gridSpecById = gridSpecById
		self._tileWorldPosByCoordKey = tileWorldPosByCoordKey
		self._tileDescriptorByCoordKey = tileDescriptorByCoordKey
		self._indexedStaticVersion = staticVersion
	end

	local occupancyVersion = if type(state.OccupancyVersion) == "number" then state.OccupancyVersion else 0
	if self._indexedOccupancyVersion ~= occupancyVersion then
		local occupiedCoordKeySet = {}
		local occupiedCoords = if type(state.OccupiedCoords) == "table" then state.OccupiedCoords else {}

		for _, coord in ipairs(occupiedCoords) do
			if type(coord) ~= "table" then
				continue
			end

			local gridId = coord.GridId
			local row = coord.Row
			local col = coord.Col
			if type(gridId) == "string" and type(row) == "number" and type(col) == "number" then
				occupiedCoordKeySet[_GetCoordKey(gridId, row, col)] = true
			end
		end

		self._occupiedCoordKeySet = occupiedCoordKeySet
		self._indexedOccupancyVersion = occupancyVersion
	end
end

function WorldController:GetGridSpecList(): { any }
	self:_EnsureIndexes()
	if #self._gridSpecsList > 0 then
		return self._gridSpecsList
	end

	if not warnedNoSyncData then
		warn("[WorldController] World grid sync data unavailable yet; returning empty grid specs")
		warnedNoSyncData = true
	end
	return {}
end

function WorldController:GetGridSpec(gridId: string): any?
	self:_EnsureIndexes()
	return self._gridSpecById[gridId]
end

function WorldController:GetStaticVersion(): number
	self:_EnsureIndexes()
	return self._indexedStaticVersion
end

function WorldController:GetOccupancyVersion(): number
	self:_EnsureIndexes()
	return self._indexedOccupancyVersion
end

function WorldController:IsCoordOccupied(coord: any): boolean
	self:_EnsureIndexes()
	return self._occupiedCoordKeySet[_GetCoordKey(coord.GridId, coord.Row, coord.Col)] == true
end

function WorldController:CoordToWorld(coord: any): Vector3
	self:_EnsureIndexes()
	local worldPos = self._tileWorldPosByCoordKey[_GetCoordKey(coord.GridId, coord.Row, coord.Col)]
	if worldPos ~= nil then
		return worldPos
	end

	local spec = self:GetGridSpec(coord.GridId)
	if spec == nil then
		error("WorldController: unknown GridId")
	end

	local specCFrame = _BuildSpecCFrame(spec)
	if specCFrame == nil then
		error("WorldController: invalid grid spec transform")
	end

	local localX = -spec.GridSizeX * 0.5 + spec.TileSize * 0.5 + (coord.Col - 1) * spec.TileSize
	local localZ = -spec.GridSizeZ * 0.5 + spec.TileSize * 0.5 + (coord.Row - 1) * spec.TileSize
	return specCFrame:PointToWorldSpace(Vector3.new(localX, 0, localZ))
end

function WorldController:WorldToCoord(worldPos: Vector3): any?
	for _, spec in ipairs(self:GetGridSpecList()) do
		local specCFrame = _BuildSpecCFrame(spec)
		if specCFrame == nil then
			continue
		end

		local localPos = specCFrame:PointToObjectSpace(worldPos)
		local col = math.floor((localPos.X + spec.GridSizeX * 0.5) / spec.TileSize) + 1
		local row = math.floor((localPos.Z + spec.GridSizeZ * 0.5) / spec.TileSize) + 1
		if row >= 1 and row <= spec.GridRows and col >= 1 and col <= spec.GridCols then
			return table.freeze({
				GridId = spec.GridId,
				Row = row,
				Col = col,
			})
		end
	end

	return nil
end

function WorldController:GetTileDescriptor(coord: any): any?
	self:_EnsureIndexes()
	return self._tileDescriptorByCoordKey[_GetCoordKey(coord.GridId, coord.Row, coord.Col)]
end

return WorldController

