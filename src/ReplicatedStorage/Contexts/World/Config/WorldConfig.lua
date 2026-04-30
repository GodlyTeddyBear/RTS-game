--!strict

--[[
    Module: WorldConfig
    Purpose: Stores shared world-grid constants used to resolve the authoritative map layout.
    Used In System: Required by server world services and client placement runtime helpers.
    Boundaries: Owns stable configuration only; does not own live grid state, runtime caching, or placement validation.
]]

local TILE_SIZE = 8

--[=[
	@class WorldConfig
	Holds shared world-grid runtime constants.
]=]
local WorldConfig = {}

-- [Constants]

--[=[
	@prop TILE_SIZE number
	@within WorldConfig
	The size of one square tile in studs.
]=]
WorldConfig.TILE_SIZE = TILE_SIZE

--[=[
	@prop GRID_PART_NAME string
	@within WorldConfig
	Marker part name used inside the runtime map `PlacementGrids` zone.
]=]
WorldConfig.GRID_PART_NAME = "PlacementGrid"

--[=[
	@prop SIDE_POCKET_COLUMN_INTERVAL number
	@within WorldConfig
	Fallback interval used for side-pocket resource alternation when no part attribute is set.
]=]
WorldConfig.SIDE_POCKET_COLUMN_INTERVAL = 4

--[=[
	@prop SPAWN_PART_NAME string
	@within WorldConfig
	Marker part name used inside the runtime map `Spawns` zone for spawn-area parts.
]=]
WorldConfig.SPAWN_PART_NAME = "Spawn"

--[=[
	@prop LANE_POINT_Y_OFFSET number
	@within WorldConfig
	Vertical offset from lane tile centers used by derived lane endpoints.
]=]
WorldConfig.LANE_POINT_Y_OFFSET = 2

return table.freeze(WorldConfig)
