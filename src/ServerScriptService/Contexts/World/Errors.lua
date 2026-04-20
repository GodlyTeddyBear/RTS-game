--!strict

--[[
	World Context - Centralized error messages

	Responsibility: Define all error constants for the World Context.
	Used by Domain and Application layers for consistent error reporting.
]]

--[=[
	@class Errors
	Error message constants for World Context operations.
	@server
]=]
return table.freeze({
	AREA_NOT_FOUND = "Lot area does not exist",
	AREA_ALREADY_CLAIMED = "Lot area is already claimed by another player",
	PLAYER_ALREADY_HAS_CLAIM = "Player already has a claimed lot area",
	PLAYER_HAS_NO_CLAIM = "Player does not have a claimed lot area",
	NO_AREAS_AVAILABLE = "No lot areas are currently available",
	RELEASE_FAILED = "Failed to release lot area claim",
	DISCOVERY_FAILED = "Failed to discover lot areas from workspace",
})
