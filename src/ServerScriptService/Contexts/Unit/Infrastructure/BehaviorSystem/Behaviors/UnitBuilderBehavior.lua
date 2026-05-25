--!strict

--[=[
    @class UnitBuilderBehavior
    Defines the builder unit behavior priority order used by the unit runtime profile.

    @server
]=]

local UnitBuilderBehavior = table.freeze({
	Priority = {
		{
			Sequence = {
				"UnitHasGoalTarget",
				"UnitManualMove",
			},
		},
		"UnitIdle",
	},
})

return UnitBuilderBehavior
