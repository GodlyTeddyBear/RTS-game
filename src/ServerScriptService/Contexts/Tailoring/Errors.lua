--!strict

--[=[
	@class Errors
	Error message constants for the Tailoring context.
	@server
]=]
return table.freeze({
	--[=[ @prop RECIPE_LOCKED string @within Errors Message shown when a recipe has not been unlocked. ]=]
	RECIPE_LOCKED = "This recipe has not been unlocked yet",

	--[=[ @prop RECIPE_NOT_FOUND string @within Errors Message shown when the recipe ID does not exist. ]=]
	RECIPE_NOT_FOUND = "Tailoring recipe does not exist",

	--[=[ @prop INSUFFICIENT_MATERIALS string @within Errors Message shown when the player lacks required ingredient quantities. ]=]
	INSUFFICIENT_MATERIALS = "Not enough materials to tailor this item",

	--[=[ @prop TAILOR_FAILED string @within Errors Message shown when tailoring failed during ingredient consumption. ]=]
	TAILOR_FAILED = "Tailoring failed unexpectedly",

	--[=[ @prop INVENTORY_NOT_FOUND string @within Errors Message shown when the player's inventory could not be found. ]=]
	INVENTORY_NOT_FOUND = "Player inventory not found",
})
