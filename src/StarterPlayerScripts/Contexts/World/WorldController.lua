--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local WorldGridSyncClient = require(script.Parent.Infrastructure.WorldGridSyncClient)

local WorldController = Knit.CreateController({
	Name = "WorldController",
})

local warnedNoSyncData = false

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
end

function WorldController:KnitStart()
	self._syncClient:Start()
end

function WorldController:GetAtom()
	return self._syncClient:GetAtom()
end

function WorldController:GetGridSpecList(): { any }
	local state = self._syncClient:GetAtom()()
	local specs = state and state.GridSpecs
	if type(specs) == "table" then
		return specs
	end

	if not warnedNoSyncData then
		warn("[WorldController] World grid sync data unavailable yet; returning empty grid specs")
		warnedNoSyncData = true
	end
	return {}
end

function WorldController:GetGridSpec(gridId: string): any?
	for _, spec in ipairs(self:GetGridSpecList()) do
		if spec.GridId == gridId then
			return spec
		end
	end
	return nil
end

function WorldController:CoordToWorld(coord: any): Vector3
	local state = self._syncClient:GetAtom()()
	local tiles = state and state.Tiles
	if type(tiles) == "table" then
		for _, tile in ipairs(tiles) do
			if tile.GridId == coord.GridId and tile.Row == coord.Row and tile.Col == coord.Col then
				return Vector3.new(tile.WorldPosX, tile.WorldPosY, tile.WorldPosZ)
			end
		end
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
	local state = self._syncClient:GetAtom()()
	local tiles = state and state.Tiles
	if type(tiles) ~= "table" then
		return nil
	end

	for _, tile in ipairs(tiles) do
		if tile.GridId == coord.GridId and tile.Row == coord.Row and tile.Col == coord.Col then
			return table.freeze({
				Zone = tile.Zone,
				ResourceType = tile.ResourceType,
				IsPlacementProhibited = tile.IsPlacementProhibited == true,
			})
		end
	end

	return nil
end

return WorldController
