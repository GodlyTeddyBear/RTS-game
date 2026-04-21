--!strict

--[=[
	@class CombatMovementConfig
	Defines SimplePath tuning for combat-owned lane movement.
	@server
	@client
]=]
local CombatMovementConfig = {}

CombatMovementConfig.WAYPOINT_ARRIVAL_THRESHOLD = 2

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

CombatMovementConfig.DEFAULT_AGENT_PARAMS = table.freeze({
	AgentRadius = 2,
	AgentHeight = 5,
	AgentCanJump = true,
})

return table.freeze(CombatMovementConfig)
