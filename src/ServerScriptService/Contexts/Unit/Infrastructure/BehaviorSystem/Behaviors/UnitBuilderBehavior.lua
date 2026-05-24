--!strict

local UnitBuilderBehavior = table.freeze({
	Priority = {
		{
			Sequence = {
				"HasGoalTarget",
				"ManualMove",
			},
		},
		"Idle",
	},
})

return UnitBuilderBehavior
