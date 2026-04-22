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
	MISSING_PLACEMENT_GRID_PART = "WorldContext: missing PlacementGrid part",
	INVALID_PLACEMENT_GRID_DIMENSIONS = "WorldContext: invalid PlacementGrid dimensions",
	MISSING_SPAWN_PART = "WorldContext: missing Spawn part",
	INVALID_SPAWN_PART = "WorldContext: configured Spawn path must resolve to BasePart",
	MISSING_GOAL_PART = "WorldContext: missing Goal part",
	INVALID_GOAL_PART = "WorldContext: configured Goal path must resolve to BasePart",
})
