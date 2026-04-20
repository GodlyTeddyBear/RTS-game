--!strict

-- Shared type definitions for the Worker system
-- Used by both client and server code

export type TWorker = {
	Id: string,
	Rank: string, -- Worker tier rank: "Apprentice" | "Journeyman" | "Master" (see WorkerConfig)
	Level: number,
	Experience: number,
	AssignedTo: string?,
	TaskTarget: string?, -- Role-specific assignment (e.g. ore type for Miner)
	LastProductionTick: number,
}

export type TWorkersState = {
	[number]: { -- userId
		[string]: TWorker, -- workerId
	},
}

return {}
