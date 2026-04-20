--!strict

--[=[
	@class Errors
	Error message constants for NPC context operations (spawning, validation, cleanup).
	@server
]=]

return table.freeze({
	INVALID_USER_ID = "Invalid user ID",
	NO_SPAWN_POINTS = "No spawn points available",
	INVALID_ADVENTURER_DATA = "Invalid adventurer data for spawning",
	INVALID_ENEMY_TYPE = "Enemy type does not exist in config",
	INVALID_ZONE_ID = "Zone ID does not exist in wave config",
	INVALID_WAVE_NUMBER = "Wave number does not exist for zone",
	NO_ADVENTURERS = "No adventurers provided for spawning",
	SPAWN_POINT_MISMATCH = "Not enough spawn points for NPC count",
	ENTITY_CREATION_FAILED = "Failed to create NPC entity",
	MODEL_CREATION_FAILED = "Failed to create NPC model",
	NO_ENTITIES_FOR_USER = "No NPC entities found for user",
})
