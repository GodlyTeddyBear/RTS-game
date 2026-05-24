--!strict

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
