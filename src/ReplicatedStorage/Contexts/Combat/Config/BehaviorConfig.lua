--!strict

--[=[
	@class BehaviorConfig
	Defines default behavior tree timing for combat enemy roles.
]=]
local BehaviorConfig = {}

BehaviorConfig.DEFAULTS_BY_ROLE = table.freeze({
	swarm = table.freeze({
		TickInterval = 0.1,
	}),
	tank = table.freeze({
		TickInterval = 0.2,
	}),
})

BehaviorConfig.DEFAULT = table.freeze({
	TickInterval = 0.15,
})

return table.freeze(BehaviorConfig)
