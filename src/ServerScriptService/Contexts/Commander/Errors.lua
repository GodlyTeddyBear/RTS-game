--!strict

--[=[
	@class Errors
	Defines the centralized commander error constants used across the context.
	@server
]=]
local Errors = {}

--[=[
	@prop INVALID_PLAYER string
	@within Errors
	Returned when a commander API requires a player argument.
]=]
Errors.INVALID_PLAYER = "CommanderContext: player is required"

--[=[
	@prop INVALID_DAMAGE_AMOUNT string
	@within Errors
	Returned when a damage amount is zero, negative, or otherwise invalid.
]=]
Errors.INVALID_DAMAGE_AMOUNT = "CommanderContext: damage amount must be a positive number"

--[=[
	@prop INVALID_SLOT string
	@within Errors
	Returned when the caller references an unknown ability slot.
]=]
Errors.INVALID_SLOT = "CommanderContext: invalid ability slot key"

--[=[
	@prop ABILITY_ON_COOLDOWN string
	@within Errors
	Returned when the requested ability is still cooling down.
]=]
Errors.ABILITY_ON_COOLDOWN = "CommanderContext: ability is on cooldown"

--[=[
	@prop INSUFFICIENT_ENERGY string
	@within Errors
	Returned when the commander cannot afford an ability cost.
]=]
Errors.INSUFFICIENT_ENERGY = "CommanderContext: not enough energy to use this ability"

--[=[
	@prop COMMANDER_NOT_FOUND string
	@within Errors
	Returned when a commander state entry does not exist for the player.
]=]
Errors.COMMANDER_NOT_FOUND = "CommanderContext: commander state not found for player"

return table.freeze(Errors)
