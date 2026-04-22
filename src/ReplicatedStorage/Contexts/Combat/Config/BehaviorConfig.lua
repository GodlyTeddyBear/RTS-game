--!strict

--[=[
	@class BehaviorConfig
	Defines default behavior tree timing for combat enemy roles.
	@server
	@client
]=]
local BehaviorConfig = {}

--[=[
	@prop DEFAULTS_BY_ROLE table
	@within BehaviorConfig
	Role-specific behavior tree tick intervals used by combat AI.
]=]
BehaviorConfig.DEFAULTS_BY_ROLE = table.freeze({
	swarm = table.freeze({
		TickInterval = 0.1,
	}),
	tank = table.freeze({
		TickInterval = 0.2,
	}),
})

--[=[
	@prop DEFAULT table
	@within BehaviorConfig
	Fallback behavior tree timing used when a role has no explicit override.
]=]
BehaviorConfig.DEFAULT = table.freeze({
	TickInterval = 0.15,
})

return table.freeze(BehaviorConfig)
