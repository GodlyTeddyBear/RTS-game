--!strict

--[[
	Lot Context - Centralized error messages

	Responsibility: Define all error constants for the Lot Context.
	Used by Domain and Application layers for consistent error reporting.
]]

--[=[
	@class Errors
	Centralized error message constants for the Lot context.
	@server
]=]

return table.freeze({
	DUPLICATE_LOT = "Player already has a lot",
	SPAWN_FAILED = "Failed to spawn lot",
	ENTITY_NOT_FOUND = "Lot entity not found for player",
})
