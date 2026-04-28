--!strict

--[=[
	@class StructureBehavior
	Defines the structure attack priority tree: enemy attack first, then idle.
	@server
]=]
local StructureBehavior = table.freeze({
	Priority = {
		{
			Sequence = {
				"HasEnemyTargetInRange",
				"StructureAttack",
			},
		},
		"Idle",
	},
})

return StructureBehavior
