--!strict

--[=[
	@class CombatMovementConfig
	Defines SimplePath tuning for combat-owned lane movement.
	@server
	@client
]=]
local CombatMovementConfig = {}

--[=[
	@prop WAYPOINT_ARRIVAL_THRESHOLD number
	@within CombatMovementConfig
	Distance threshold used to treat an enemy as having reached a waypoint.
]=]
CombatMovementConfig.WAYPOINT_ARRIVAL_THRESHOLD = 2

--[=[
	@prop AGENT_PARAMS_BY_ROLE table
	@within CombatMovementConfig
	Role-specific SimplePath agent settings used by lane movement.
]=]
CombatMovementConfig.AGENT_PARAMS_BY_ROLE = table.freeze({
	swarm = table.freeze({
		AgentRadius = 1.5,
		AgentHeight = 5,
		AgentCanJump = false,
	}),
	tank = table.freeze({
		AgentRadius = 2.5,
		AgentHeight = 6,
		AgentCanJump = false,
	}),
})

--[=[
	@prop DEFAULT_AGENT_PARAMS table
	@within CombatMovementConfig
	Default SimplePath agent settings used when a role has no override.
]=]
CombatMovementConfig.DEFAULT_AGENT_PARAMS = table.freeze({
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
})

return table.freeze(CombatMovementConfig)
