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
	@prop RESOURCE_ZONE_NAME string
	@within WorldConfig
	Zone name used for authored resource parts that mark extractor-valid tiles.
]=]
WorldConfig.RESOURCE_ZONE_NAME = "Resources"

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

--[=[
	@prop PLACEMENT_BLACKLIST_NAMES { string }
	@within WorldConfig
	Case-insensitive exact-name blacklist for runtime-map instances whose descendant parts should prohibit placement.
]=]
WorldConfig.PLACEMENT_BLACKLIST_NAMES = {
	"Bound",
}

return table.freeze(WorldConfig)
