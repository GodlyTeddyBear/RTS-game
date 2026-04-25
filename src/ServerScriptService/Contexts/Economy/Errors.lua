--!strict

--[[
	Module: Errors
	Purpose: Defines the centralized Economy context error constants.
	Used In System: Imported by commands, queries, validators, and persistence helpers.
	Boundaries: Owns error strings only; does not own error handling or logging policy.
]]

-- [Constants]

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
	@prop INVALID_COST_MAP string
	@within Errors
	Returned when a multi-resource spend map is missing or malformed.
]=]
Errors.INVALID_COST_MAP = "EconomyContext: resource cost map must contain at least one positive integer cost"

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

--[=[
	@prop INVALID_RUN_STATS string
	@within Errors
	Returned when run stats payload is missing or malformed.
]=]
Errors.INVALID_RUN_STATS = "EconomyContext: run stats are required"

--[=[
	@prop INVALID_WAVE_NUMBER string
	@within Errors
	Returned when a wave number is missing or invalid.
]=]
Errors.INVALID_WAVE_NUMBER = "EconomyContext: wave number must be a positive integer"

--[=[
	@prop PERSISTENCE_PROFILE_NOT_LOADED string
	@within Errors
	Returned when persistence is requested before profile data is available.
]=]
Errors.PERSISTENCE_PROFILE_NOT_LOADED = "EconomyPersistence: profile data is not loaded"

--[=[
	@prop PERSISTENCE_RUN_STATS_MUST_BE_TABLE string
	@within Errors
	Returned when `profile.Data.RunStats` is not a table.
]=]
Errors.PERSISTENCE_RUN_STATS_MUST_BE_TABLE = "EconomyPersistence: run stats must be a table"

--[=[
	@prop PERSISTENCE_RUN_STATS_FIELDS_MUST_BE_NUMBERS string
	@within Errors
	Returned when one or more run stat fields are not numbers.
]=]
Errors.PERSISTENCE_RUN_STATS_FIELDS_MUST_BE_NUMBERS = "EconomyPersistence: run stats fields must be numbers"

return table.freeze(Errors)
