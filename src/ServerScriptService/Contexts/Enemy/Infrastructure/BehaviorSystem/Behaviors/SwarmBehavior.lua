--!strict

--[=[
	@class SwarmBehavior
	Defines the swarm enemy priority tree: structure attack, base attack, advance, then idle.
	@server
]=]
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
