--!strict

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
