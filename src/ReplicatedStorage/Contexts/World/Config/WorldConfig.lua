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
	@prop GRID_PART_PATH string
	@within WorldConfig
	Dot-path to the authoritative placement grid part in Workspace.
]=]
WorldConfig.GRID_PART_PATH = "Workspace.Map.Game.Environment.Zones.PlacementGrid"

--[=[
	@prop SIDE_POCKET_COLUMN_INTERVAL number
	@within WorldConfig
	Fallback interval used for side-pocket resource alternation when no part attribute is set.
]=]
WorldConfig.SIDE_POCKET_COLUMN_INTERVAL = 4

--[=[
	@prop SIDE_POCKETS_PATH string
	@within WorldConfig
	Dot-path to the Studio-authored side-pocket container.
]=]
WorldConfig.SIDE_POCKETS_PATH = "Workspace.Map.Game.Environment.Zones.SidePockets"

--[=[
	@prop GOAL_PART_PATH string
	@within WorldConfig
	Dot-path to the authoritative enemy goal BasePart in Workspace.
]=]
WorldConfig.GOAL_PART_PATH = "Workspace.Map.Game.Environment.Zones.Goal"

--[=[
	@prop LANE_POINT_Y_OFFSET number
	@within WorldConfig
	Vertical offset (from lane tile centers) used by spawn/goal points.
]=]
WorldConfig.LANE_POINT_Y_OFFSET = 2

return table.freeze(WorldConfig)
