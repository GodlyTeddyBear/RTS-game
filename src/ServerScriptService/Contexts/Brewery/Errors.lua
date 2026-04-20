--!strict

--[=[
	@class Errors
	Error message constants for the Brewery context.
	@server
]=]

--[=[
	@interface BreweryErrors
	@within Errors
	.RECIPE_LOCKED string -- Recipe has not been unlocked by the player
	.RECIPE_NOT_FOUND string -- Recipe does not exist in configuration
	.INSUFFICIENT_MATERIALS string -- Player lacks required ingredient quantities
	.BREW_FAILED string -- Brew operation failed during ingredient consumption or item creation
	.INVENTORY_NOT_FOUND string -- Player inventory not found or inaccessible
]=]

return table.freeze({
	RECIPE_LOCKED = "This recipe has not been unlocked yet",
	RECIPE_NOT_FOUND = "Brewery recipe does not exist",
	INSUFFICIENT_MATERIALS = "Not enough materials to brew this potion",
	BREW_FAILED = "Brewing failed unexpectedly",
	INVENTORY_NOT_FOUND = "Player inventory not found",
})
