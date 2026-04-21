--!strict

--[=[
	@class EnemyMovementConfig
	Defines SimplePath tuning for phase-0 enemy movement.
	@server
	@client
]=]
local EnemyMovementConfig = {}

EnemyMovementConfig.WAYPOINT_ARRIVAL_THRESHOLD = 2

EnemyMovementConfig.AGENT_PARAMS_BY_ROLE = table.freeze({
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

return table.freeze(EnemyMovementConfig)
