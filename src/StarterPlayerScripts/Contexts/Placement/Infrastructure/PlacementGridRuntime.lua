--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type GridCoord = WorldTypes.GridCoord
type TileDescriptor = WorldTypes.TileDescriptor
type GridSpec = WorldTypes.GridSpec

local PlacementGridRuntime = {}

local warnedNoSyncData = false

local function _GetWorldController()
	return Knit.GetController("WorldController")
end

local function _BuildSpecCFrame(rawSpec: any): CFrame
	local origin = Vector3.new(rawSpec.OriginX, rawSpec.OriginY, rawSpec.OriginZ)
	local right = Vector3.new(rawSpec.RightX, rawSpec.RightY, rawSpec.RightZ)
	local up = Vector3.new(rawSpec.UpX, rawSpec.UpY, rawSpec.UpZ)
	local look = Vector3.new(rawSpec.LookX, rawSpec.LookY, rawSpec.LookZ)
	return CFrame.fromMatrix(origin, right, up, -look)
end

local function _ToGridSpec(rawSpec: any): GridSpec?
	if type(rawSpec) ~= "table" then
		return nil
	end

	if type(rawSpec.GridId) ~= "string" then
		return nil
	end

	if type(rawSpec.GridRows) ~= "number" or type(rawSpec.GridCols) ~= "number" then
		return nil
	end

	if
		type(rawSpec.GridSizeX) ~= "number"
		or type(rawSpec.GridSizeY) ~= "number"
		or type(rawSpec.GridSizeZ) ~= "number"
		or type(rawSpec.TileSize) ~= "number"
	then
		return nil
	end

	if
		type(rawSpec.OriginX) ~= "number"
		or type(rawSpec.OriginY) ~= "number"
		or type(rawSpec.OriginZ) ~= "number"
		or type(rawSpec.RightX) ~= "number"
		or type(rawSpec.RightY) ~= "number"
		or type(rawSpec.RightZ) ~= "number"
		or type(rawSpec.UpX) ~= "number"
		or type(rawSpec.UpY) ~= "number"
		or type(rawSpec.UpZ) ~= "number"
		or type(rawSpec.LookX) ~= "number"
		or type(rawSpec.LookY) ~= "number"
		or type(rawSpec.LookZ) ~= "number"
	then
		return nil
	end

	local sidePocketRows = {}
	local laneRow = if type(rawSpec.LaneRow) == "number" then rawSpec.LaneRow else 1
	if laneRow - 1 >= 1 then
		table.insert(sidePocketRows, laneRow - 1)
	end
	if laneRow + 1 <= rawSpec.GridRows then
		table.insert(sidePocketRows, laneRow + 1)
	end

	return table.freeze({
		GridId = rawSpec.GridId,
		GridCFrame = _BuildSpecCFrame(rawSpec),
		GridSize = Vector3.new(rawSpec.GridSizeX, rawSpec.GridSizeY, rawSpec.GridSizeZ),
		TileSize = rawSpec.TileSize,
		GridRows = rawSpec.GridRows,
		GridCols = rawSpec.GridCols,
		LaneRow = laneRow,
		SidePocketRows = table.freeze(sidePocketRows),
	})
end

function PlacementGridRuntime.GetGridSpecList(): { GridSpec }
	local worldController = _GetWorldController()
	local rawSpecs = worldController:GetGridSpecList()
	local specs = {}

	for _, rawSpec in ipairs(rawSpecs) do
		local spec = _ToGridSpec(rawSpec)
		if spec ~= nil then
			table.insert(specs, spec)
		end
	end

	if #specs == 0 and not warnedNoSyncData then
		warn("[PlacementGridRuntime] World grid sync data unavailable; placement will retry when sync hydrates.")
		warnedNoSyncData = true
	end

	table.sort(specs, function(left: GridSpec, right: GridSpec): boolean
		return left.GridId < right.GridId
	end)

	return table.freeze(specs)
end

function PlacementGridRuntime.GetGridSpecs(): { [string]: GridSpec }
	local byId = {}
	for _, spec in ipairs(PlacementGridRuntime.GetGridSpecList()) do
		byId[spec.GridId] = spec
	end
	return byId
end

function PlacementGridRuntime.GetGridSpec(gridId: string): GridSpec?
	return PlacementGridRuntime.GetGridSpecs()[gridId]
end

function PlacementGridRuntime.ResetCache()
	return
end

function PlacementGridRuntime.GetStaticVersion(): number
	return _GetWorldController():GetStaticVersion()
end

function PlacementGridRuntime.CoordToWorld(coord: GridCoord): Vector3
	return _GetWorldController():CoordToWorld(coord)
end

function PlacementGridRuntime.WorldToCoord(worldPos: Vector3): GridCoord?
	return _GetWorldController():WorldToCoord(worldPos)
end

function PlacementGridRuntime.GetTileDescriptor(coord: GridCoord): TileDescriptor?
	return _GetWorldController():GetTileDescriptor(coord)
end

return table.freeze(PlacementGridRuntime)
