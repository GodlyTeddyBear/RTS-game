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
})
