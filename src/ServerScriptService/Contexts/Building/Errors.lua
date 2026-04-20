--!strict

--[=[
	@class Errors
	Defines canonical error messages used by the building context.
	@server
]=]
local Errors = {
	BUILDING_LOCKED = "This building has not been unlocked yet",
	INVALID_ZONE = "Zone does not exist for player",
	SLOT_OCCUPIED = "Building slot is already occupied",
	SLOT_EMPTY = "Building slot is empty",
	SLOT_OUT_OF_RANGE = "Slot index exceeds zone max slots",
	UNKNOWN_BUILDING_TYPE = "Building type is not defined in config",
	CANNOT_AFFORD = "Player cannot afford this building",
	BUILDING_NOT_FOUND = "Building entity not found",
	MAX_LEVEL_REACHED = "Building is already at max level",

	NOT_FUEL_MACHINE = "This building does not accept fuel",
	INSUFFICIENT_FUEL_IN_INVENTORY = "Not enough fuel items in inventory",
	NO_PROFILE_DATA = "Player profile not loaded",
	MACHINE_QUEUE_FULL = "Machine queue is full",
	INVALID_MACHINE_RECIPE = "This recipe cannot be processed here",
	NO_MACHINE_OUTPUT = "Nothing to collect from this machine",
	INSUFFICIENT_MACHINE_INGREDIENTS = "Not enough materials in inventory for this recipe",
}

--[=[
	@prop BUILDING_LOCKED string
	@within Errors
	Error message when the target building has not been unlocked.
]=]

--[=[
	@prop INVALID_ZONE string
	@within Errors
	Error message when zone lookup fails for a player.
]=]

--[=[
	@prop SLOT_OCCUPIED string
	@within Errors
	Error message when constructing into an occupied slot.
]=]

--[=[
	@prop SLOT_EMPTY string
	@within Errors
	Error message when acting on an empty slot.
]=]

--[=[
	@prop SLOT_OUT_OF_RANGE string
	@within Errors
	Error message when slot index exceeds zone capacity.
]=]

--[=[
	@prop UNKNOWN_BUILDING_TYPE string
	@within Errors
	Error message when building config key is unknown.
]=]

--[=[
	@prop CANNOT_AFFORD string
	@within Errors
	Error message when player lacks required currency.
]=]

--[=[
	@prop BUILDING_NOT_FOUND string
	@within Errors
	Error message when ECS building entity cannot be found.
]=]

--[=[
	@prop MAX_LEVEL_REACHED string
	@within Errors
	Error message when upgrade target is already max level.
]=]

--[=[
	@prop NOT_FUEL_MACHINE string
	@within Errors
	Error message when machine action targets non-fuel building.
]=]

--[=[
	@prop INSUFFICIENT_FUEL_IN_INVENTORY string
	@within Errors
	Error message when inventory has insufficient fuel items.
]=]

--[=[
	@prop NO_PROFILE_DATA string
	@within Errors
	Error message when profile data is unavailable.
]=]

--[=[
	@prop MACHINE_QUEUE_FULL string
	@within Errors
	Error message when recipe queue has reached capacity.
]=]

--[=[
	@prop INVALID_MACHINE_RECIPE string
	@within Errors
	Error message when recipe does not match machine eligibility.
]=]

--[=[
	@prop NO_MACHINE_OUTPUT string
	@within Errors
	Error message when no machine output can be claimed.
]=]

--[=[
	@prop INSUFFICIENT_MACHINE_INGREDIENTS string
	@within Errors
	Error message when required machine ingredients are missing.
]=]

return Errors
