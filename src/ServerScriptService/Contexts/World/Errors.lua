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
	MISSING_PLACEMENT_GRID_ID = "WorldContext: PlacementGrid part is missing required GridId attribute",
	DUPLICATE_PLACEMENT_GRID_ID = "WorldContext: duplicate PlacementGrid GridId detected",
	OVERLAPPING_PLACEMENT_GRIDS = "WorldContext: PlacementGrid parts overlap in XZ and cannot coexist",
	MISSING_SPAWN_PART = "WorldContext: missing Spawns runtime zone or Spawn area marker",
	INVALID_SPAWN_PART = "WorldContext: Spawns runtime zone must contain a valid BasePart named Spawn",
})
