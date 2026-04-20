--!strict

--[=[
	@class Errors
	Error message constants for the Villager context.
	@server
]=]

return table.freeze({
	NO_ARCHETYPE = "Villager archetype does not exist",
	NO_SPAWN_POINT = "No villager spawn point is available",
	NO_EXIT_POINT = "No villager exit point is available",
	NO_ELIGIBLE_LOT = "No eligible player lot is available",
	MODEL_CREATE_FAILED = "Could not create villager model",
	INVALID_VILLAGER_ID = "Invalid villager ID",
})
