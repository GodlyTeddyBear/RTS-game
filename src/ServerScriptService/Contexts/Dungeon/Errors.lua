--!strict

--[=[
	@class Errors
	Error message constants for the Dungeon context.
	@server
]=]

return table.freeze({
	ZONE_NOT_FOUND = "Zone does not exist",
	DUNGEON_ALREADY_ACTIVE = "A dungeon is already active for this player",
	NO_ACTIVE_DUNGEON = "No active dungeon found",
	DUNGEON_NOT_ACTIVE = "Dungeon is not in active state",
	WAVE_OUT_OF_RANGE = "Wave number is out of range",
	PLAYER_NOT_FOUND = "Player data not available",
	MISSING_ZONE_ASSETS = "Zone assets folder not found",
	MISSING_START_PIECE = "Start piece not found in zone assets",
	MISSING_END_PIECE = "End piece not found in zone assets",
	MISSING_AREA_PIECES = "No area pieces found in zone assets",
	LOT_POSITION_NOT_FOUND = "Could not find lot spawn position for player",
})
