--!strict

--[=[
	@class Errors
	Error message constants for the PlayerCommand context.
	@server
]=]

--[=[
	@prop INVALID_USER_ID string
	@within Errors
	Returned when the provided user ID is not valid.
]=]

--[=[
	@prop NO_ACTIVE_COMBAT string
	@within Errors
	Returned when no active combat session exists for the user.
]=]

--[=[
	@prop COMBAT_PAUSED string
	@within Errors
	Returned when commands are blocked because combat is paused.
]=]

--[=[
	@prop INVALID_COMMAND_TYPE string
	@within Errors
	Returned when the command type string is unrecognised.
]=]

--[=[
	@prop NO_NPC_IDS string
	@within Errors
	Returned when the NPC ID list is empty or missing.
]=]

--[=[
	@prop NPC_NOT_FOUND string
	@within Errors
	Returned when no ECS entity exists for the given NPC ID.
]=]

--[=[
	@prop NPC_NOT_ALIVE string
	@within Errors
	Returned when the NPC entity exists but is not alive.
]=]

--[=[
	@prop NPC_NOT_ADVENTURER string
	@within Errors
	Returned when the NPC is not an adventurer and therefore cannot receive commands.
]=]

--[=[
	@prop NPC_NOT_OWNED string
	@within Errors
	Returned when the NPC does not belong to the requesting player.
]=]

--[=[
	@prop INVALID_POSITION string
	@within Errors
	Returned when the target position in command data is not a valid `Vector3`.
]=]

--[=[
	@prop TARGET_NOT_FOUND string
	@within Errors
	Returned when the attack target entity cannot be located.
]=]

--[=[
	@prop TARGET_NOT_ALIVE string
	@within Errors
	Returned when the attack target exists but is not alive.
]=]

--[=[
	@prop TARGET_NOT_ENEMY string
	@within Errors
	Returned when the attack target is not an enemy NPC.
]=]

--[=[
	@prop RATE_LIMITED string
	@within Errors
	Returned when the player has exceeded the command rate limit.
]=]

return table.freeze({
	INVALID_USER_ID = "Invalid user ID",
	NO_ACTIVE_COMBAT = "No active combat found for this user",
	COMBAT_PAUSED = "Cannot issue commands while combat is paused",
	INVALID_COMMAND_TYPE = "Invalid command type",
	NO_NPC_IDS = "No NPC IDs provided",
	NPC_NOT_FOUND = "NPC entity not found",
	NPC_NOT_ALIVE = "NPC is not alive",
	NPC_NOT_ADVENTURER = "Can only command adventurer NPCs",
	NPC_NOT_OWNED = "NPC does not belong to this player",
	INVALID_POSITION = "Invalid target position",
	TARGET_NOT_FOUND = "Attack target not found",
	TARGET_NOT_ALIVE = "Attack target is not alive",
	TARGET_NOT_ENEMY = "Can only target enemy NPCs",
	RATE_LIMITED = "Command rate limit exceeded",
})
