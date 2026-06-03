--!strict

export type TEntityPhases = {
	SchedulerPhase: string,
	MovementSchedulerPhase: string,
	Ordered: { string },
	MovementOrdered: { string },
	RuntimeOrdered: { string },
}

local movementOrdered = table.freeze({
	"MovementGrid",
	"MovementCalculate",
	"MovementApply",
})

local runtimeOrdered = table.freeze({
	"PreSimulation",
	"Simulation",
	"PostSimulation",
	"Sense",
	"Decide",
	"Commit",
	"ActionStart",
	"ActionAdvance",
	"MechanicSpawn",
	"MechanicImpact",
	"DamageResolve",
	"RequestResolve",
	"Execute",
	"CleanupResolve",
	"Cleanup",
})

local EntityPhases: TEntityPhases = table.freeze({
	SchedulerPhase = "CombatTick",
	MovementSchedulerPhase = "MovementTick",
	MovementOrdered = movementOrdered,
	RuntimeOrdered = runtimeOrdered,
	Ordered = table.freeze({
		"MovementGrid",
		"MovementCalculate",
		"MovementApply",
		"PreSimulation",
		"Simulation",
		"PostSimulation",
		"Sense",
		"Decide",
		"Commit",
		"ActionStart",
		"ActionAdvance",
		"MechanicSpawn",
		"MechanicImpact",
		"DamageResolve",
		"RequestResolve",
		"Execute",
		"CleanupResolve",
		"Cleanup",
	}),
})

return EntityPhases
