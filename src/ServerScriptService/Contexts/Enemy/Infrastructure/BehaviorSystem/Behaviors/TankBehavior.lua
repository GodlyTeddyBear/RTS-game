--!strict

--[=[
	@class TankBehavior
	Defines the tank enemy priority tree, which matches the swarm flow for this context.
	@server
]=]
local TankBehavior = table.freeze({
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

return TankBehavior
