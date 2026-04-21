--!strict

--[=[
	@class Errors
	Defines the centralized Economy context error constants.
	@server
]=]
local Errors = {}

--[=[
	@prop INVALID_PLAYER string
	@within Errors
	Returned when a context method requires a player argument.
]=]
Errors.INVALID_PLAYER = "EconomyContext: player is required"

--[=[
	@prop INVALID_AMOUNT string
	@within Errors
	Returned when a resource amount is zero, negative, or fractional.
]=]
Errors.INVALID_AMOUNT = "EconomyContext: amount must be a positive integer"

--[=[
	@prop UNKNOWN_RESOURCE_TYPE string
	@within Errors
	Returned when the caller passes a resource name that is not configured.
]=]
Errors.UNKNOWN_RESOURCE_TYPE = "EconomyContext: unknown resource type"

--[=[
	@prop PLAYER_NOT_INITIALIZED string
	@within Errors
	Returned when the wallet entry does not exist yet for the target player.
]=]
Errors.PLAYER_NOT_INITIALIZED = "EconomyContext: player wallet not initialized"

--[=[
	@prop INSUFFICIENT_RESOURCES string
	@within Errors
	Returned when a spend request exceeds the current balance.
]=]
Errors.INSUFFICIENT_RESOURCES = "EconomyContext: insufficient resources"

--[=[
	@prop INVALID_GRANT string
	@within Errors
	Returned when a pickup grant payload is missing.
]=]
Errors.INVALID_GRANT = "EconomyContext: pickup grant is required"

--[=[
	@prop INVALID_GRANT_RESOURCE_TYPE string
	@within Errors
	Returned when a pickup grant omits its resource type.
]=]
Errors.INVALID_GRANT_RESOURCE_TYPE = "EconomyContext: pickup grant missing resourceType"

--[=[
	@prop INVALID_GRANT_AMOUNT string
	@within Errors
	Returned when a pickup grant omits its amount.
]=]
Errors.INVALID_GRANT_AMOUNT = "EconomyContext: pickup grant missing amount"

return table.freeze(Errors)
