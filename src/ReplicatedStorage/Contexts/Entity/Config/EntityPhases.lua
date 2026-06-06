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
	"MovementFinalize",
	"MovementActionComplete",
})

local runtimeOrdered = table.freeze({
	"PreSimulation",
	"Simulation",
	"PostSimulation",
	"Sense",
	"RuntimePoll",
	"Decide",
	"Commit",
	"ActionStart",
	"ActionReconcile",
	"ActionAdvance",
	"MechanicSpawn",
	"MechanicImpact",
	"HealthResolve",
	"OutcomeDispatch",
	"RequestResolve",
	"Projection",
	"CleanupResolve",
	"Cleanup",
	"RuntimeSync",
	"DestroyFlush",
})

local EntityPhases: TEntityPhases = table.freeze({
	SchedulerPhase = "EntityTick",
	MovementSchedulerPhase = "MovementTick",
	MovementOrdered = movementOrdered,
	RuntimeOrdered = runtimeOrdered,
	Ordered = table.freeze({
		"MovementGrid",
		"MovementCalculate",
		"MovementApply",
		"MovementFinalize",
		"MovementActionComplete",
		"PreSimulation",
		"Simulation",
		"PostSimulation",
		"Sense",
		"RuntimePoll",
		"Decide",
		"Commit",
		"ActionStart",
		"ActionReconcile",
		"ActionAdvance",
		"MechanicSpawn",
		"MechanicImpact",
		"HealthResolve",
		"OutcomeDispatch",
		"RequestResolve",
		"Projection",
		"CleanupResolve",
		"Cleanup",
		"RuntimeSync",
		"DestroyFlush",
	}),
})

return EntityPhases
