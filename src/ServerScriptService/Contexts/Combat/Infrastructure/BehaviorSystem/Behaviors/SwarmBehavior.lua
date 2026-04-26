--!strict

local SwarmBehavior = table.freeze({
	Priority = {
		{
			Sequence = {
				"HasStructureTargetInRange",
				"AttackStructure",
			},
		},
		{
			Sequence = {
				"HasBaseTargetInRange",
				"AttackBase",
			},
		},
		{
			Sequence = {
				"HasGoalTarget",
				"Advance",
			},
		},
		"Idle",
	},
})

return SwarmBehavior
