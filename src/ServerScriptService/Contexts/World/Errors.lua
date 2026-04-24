--!strict

--[=[
	@class Errors
	Defines the world context error constants.
	@server
]=]
return table.freeze({
	INVALID_COORD = "Grid coordinate is invalid",
	OUT_OF_BOUNDS = "Grid coordinate is out of bounds",
	TILE_NOT_FOUND = "Tile not found",
	MISSING_PLACEMENT_GRID_PART = "WorldContext: missing PlacementGrid part in runtime map PlacementGrids zone",
	INVALID_PLACEMENT_GRID_DIMENSIONS = "WorldContext: invalid PlacementGrid dimensions",
	MISSING_SPAWN_PART = "WorldContext: missing Spawns runtime zone or Spawn marker",
	INVALID_SPAWN_PART = "WorldContext: Spawns runtime zone must contain a BasePart named Spawn",
	MISSING_GOAL_PART = "WorldContext: missing Goals runtime zone or Goal marker",
	INVALID_GOAL_PART = "WorldContext: Goals runtime zone must contain a BasePart named Goal",
})
