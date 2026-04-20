--!strict

--[=[
	@class NPCConfig
	Configuration constants for NPC entity creation, behavior tree ticking, combat synchronization, and model tagging.
	@server
]=]

return table.freeze({
	DEFAULT_DETECTION_RADIUS = 200,
	DEFAULT_ATTACK_RANGE = 5,
	DEFAULT_ATTACK_COOLDOWN = 1.5,

	-- BT tick interval range (randomized per NPC for staggering)
	BT_TICK_MIN_INTERVAL = 0.2,
	BT_TICK_MAX_INTERVAL = 0.5,

	-- Combat state sync frequency to client
	COMBAT_SYNC_INTERVAL = 0.2, -- 5Hz

	-- NPC model tags
	COMBAT_NPC_TAG = "CombatNPC",

	-- NPC collision group settings (all combat NPCs share this group)
	NPC_COLLISION_GROUP = "CombatNPC",
	NPC_COLLIDES_WITH_NPC = false,
})
