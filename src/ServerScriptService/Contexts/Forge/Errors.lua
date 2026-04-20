--!strict

--[=[
	@class Errors
	Error message constants for the Forge context. Used in Result types and error reporting.
	@server
]=]

--[=[
	@prop RECIPE_NOT_FOUND string
	@within Errors
	Recipe ID does not map to a known recipe in configuration.
]=]

--[=[
	@prop INSUFFICIENT_MATERIALS string
	@within Errors
	Player inventory lacks required ingredient quantities for this recipe.
]=]

--[=[
	@prop USE_MACHINE_FOR_RECIPE string
	@within Errors
	Recipe requires use of a machine (multi-step process) and cannot be crafted instantly.
]=]

--[=[
	@prop CRAFT_FAILED string
	@within Errors
	Crafting operation failed after validation (e.g., inventory mutation race condition).
]=]

--[=[
	@prop INVENTORY_NOT_FOUND string
	@within Errors
	Player's inventory context or state could not be retrieved.
]=]

return table.freeze({
	RECIPE_NOT_FOUND = "Recipe does not exist",
	RECIPE_LOCKED = "This recipe has not been unlocked yet",
	REQUIRED_BUILDING_MISSING = "Required forge building is not available in your lot",
	INSUFFICIENT_MATERIALS = "Not enough materials to craft this item",
	USE_MACHINE_FOR_RECIPE = "Craft this recipe at the building on your lot",
	CRAFT_FAILED = "Crafting failed unexpectedly",
	INVENTORY_NOT_FOUND = "Player inventory not found",
})
