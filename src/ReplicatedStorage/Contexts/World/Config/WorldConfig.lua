--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldTypes = require(ReplicatedStorage.Contexts.World.Types.WorldTypes)

type TileDescriptor = WorldTypes.TileDescriptor
type ZoneLayout = WorldTypes.ZoneLayout

local GRID_COLS = 20
local GRID_ROWS = 5
local TILE_SIZE = 8

local WORLD_ORIGIN = CFrame.new(0, 0, 0)

local function laneTile(): TileDescriptor
	return table.freeze({
		zone = "lane",
	})
end

local function blockedTile(): TileDescriptor
	return table.freeze({
		zone = "blocked",
	})
end

local function sidePocketTile(resourceType: string): TileDescriptor
	return table.freeze({
		zone = "side_pocket",
		resourceType = resourceType,
	})
end

local function buildZoneLayout(): ZoneLayout
	local zoneLayout = table.create(GRID_ROWS)

	for row = 1, GRID_ROWS do
		local zoneRow = table.create(GRID_COLS)

		for col = 1, GRID_COLS do
			-- Keep the lane on the center row so the path stays straight and readable.
			if row == 3 then
				zoneRow[col] = laneTile()
			elseif (row == 2 or row == 4) and (col % 4 == 0) then
				-- Alternate resource pockets so the lane has multiple extraction options.
				local resourceType = if (col / 4) % 2 == 0 then "Crystal" else "Metal"
				zoneRow[col] = sidePocketTile(resourceType)
			else
				zoneRow[col] = blockedTile()
			end
		end

		zoneLayout[row] = table.freeze(zoneRow)
	end

	return table.freeze(zoneLayout)
end

--[=[
	@class WorldConfig
	Holds the shared world grid and lane configuration.
]=]
local WorldConfig = {}

--[=[
	@prop GRID_COLS number
	@within WorldConfig
	The number of columns in the world grid.
]=]
WorldConfig.GRID_COLS = GRID_COLS

--[=[
	@prop GRID_ROWS number
	@within WorldConfig
	The number of rows in the world grid.
]=]
WorldConfig.GRID_ROWS = GRID_ROWS

--[=[
	@prop TILE_SIZE number
	@within WorldConfig
	The size of each tile in studs.
]=]
WorldConfig.TILE_SIZE = TILE_SIZE

--[=[
	@prop WORLD_ORIGIN CFrame
	@within WorldConfig
	The top-left world-space origin of the grid.
]=]
WorldConfig.WORLD_ORIGIN = WORLD_ORIGIN

--[=[
	@prop SPAWN_POINTS { CFrame }
	@within WorldConfig
	The configured enemy spawn points.
]=]
WorldConfig.SPAWN_POINTS = table.freeze({
	CFrame.new(-TILE_SIZE, 2, (math.floor(GRID_ROWS / 2)) * TILE_SIZE),
})

--[=[
	@prop GOAL_POINT CFrame
	@within WorldConfig
	The commander goal point.
]=]
WorldConfig.GOAL_POINT = CFrame.new(GRID_COLS * TILE_SIZE, 2, (math.floor(GRID_ROWS / 2)) * TILE_SIZE)

--[=[
	@prop ZONE_LAYOUT ZoneLayout
	@within WorldConfig
	The row-major tile descriptors that define the lane and side pockets.
]=]
WorldConfig.ZONE_LAYOUT = buildZoneLayout()

return table.freeze(WorldConfig)
