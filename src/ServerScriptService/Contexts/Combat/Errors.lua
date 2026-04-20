--!strict

--[=[
	@class Errors
	Error message constants for the Combat context.
	@server
]=]

return table.freeze({
	INVALID_USER_ID = "Invalid user ID",
	NO_ADVENTURER_ENTITIES = "No adventurer entities provided",
	NO_ENEMY_ENTITIES = "No enemy entities provided",
	COMBAT_ALREADY_ACTIVE = "Combat is already active for this user",
	NO_ACTIVE_COMBAT = "No active combat found for this user",
	COMBAT_START_FAILED = "Failed to start combat loop",
	WAVE_TRANSITION_FAILED = "Failed to transition to next wave",
	INVALID_COMMAND = "Invalid tactical command",
	ACTION_NOT_FOUND = "Action not found in registry",
	ACTION_START_FAILED = "Action failed to start",
	ACTION_ALREADY_COMMITTED = "Cannot interrupt a committed action",

	-- Tick system specs
	IS_MANUAL_MODE = "NPC is in manual control mode",
	ACTION_IS_COMMITTED = "Current action is committed and cannot be interrupted",
	BT_NOT_READY = "Behavior tree tick interval has not elapsed",
	NO_BEHAVIOR_TREE = "Entity has no behavior tree assigned",
	WAVE_NOT_COMPLETE = "Enemies are still alive",
	PARTY_NOT_WIPED = "Adventurers are still alive",
})
