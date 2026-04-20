--!strict

--[=[
	@class Errors
	Error message constants for the Dialogue context.
	@server
]=]

--[=[
	@prop INVALID_USER_ID string
	@within Errors
	Raised when user ID is not a positive number.
]=]

--[=[
	@prop INVALID_NPC_ID string
	@within Errors
	Raised when NPC ID is empty or invalid.
]=]

--[=[
	@prop INVALID_FLAG_NAME string
	@within Errors
	Raised when a dialogue flag name violates naming constraints.
]=]

--[=[
	@prop INVALID_FLAG_VALUE string
	@within Errors
	Raised when a flag value is not boolean, string, or number.
]=]

--[=[
	@prop PLAYER_FLAGS_NOT_LOADED string
	@within Errors
	Raised when flags are accessed before player initialization.
]=]

--[=[
	@prop DIALOGUE_TREE_NOT_FOUND string
	@within Errors
	Raised when no dialogue tree exists for the requested NPC.
]=]

--[=[
	@prop DIALOGUE_NODE_NOT_FOUND string
	@within Errors
	Raised when a dialogue node ID does not exist in the tree.
]=]

--[=[
	@prop DIALOGUE_SESSION_NOT_FOUND string
	@within Errors
	Raised when player attempts an action without an active session.
]=]

--[=[
	@prop DIALOGUE_OPTION_NOT_FOUND string
	@within Errors
	Raised when an option ID is not available or does not meet flag requirements.
]=]

--[=[
	@prop PERSISTENCE_FAILED string
	@within Errors
	Raised when dialogue flag persistence to profile fails.
]=]

return table.freeze({
	INVALID_USER_ID = "User ID must be a positive number",
	INVALID_NPC_ID = "NPC ID must be a non-empty string",
	INVALID_FLAG_NAME = "Flag name is invalid",
	INVALID_FLAG_VALUE = "Flag value must be boolean, string, or number",
	PLAYER_FLAGS_NOT_LOADED = "Dialogue flags are not loaded for this player",
	DIALOGUE_TREE_NOT_FOUND = "No dialogue tree exists for this NPC",
	DIALOGUE_NODE_NOT_FOUND = "Dialogue node was not found",
	DIALOGUE_SESSION_NOT_FOUND = "No active dialogue session",
	DIALOGUE_OPTION_NOT_FOUND = "Dialogue option was not found",
	PERSISTENCE_FAILED = "Failed to persist dialogue flags",
})
