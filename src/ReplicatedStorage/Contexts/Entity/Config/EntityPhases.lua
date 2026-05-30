--!strict

export type TEntityPhases = {
	SchedulerPhase: string,
	Ordered: { string },
}

local EntityPhases: TEntityPhases = table.freeze({
	SchedulerPhase = "CombatTick",
	Ordered = table.freeze({
		"PreSimulation",
		"Simulation",
		"PostSimulation",
		"Sense",
		"Decide",
		"Commit",
		"ActionStart",
		"ActionAdvance",
		"RequestResolve",
		"Execute",
		"Cleanup",
	}),
})

return EntityPhases
