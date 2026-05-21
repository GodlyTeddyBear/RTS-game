--!strict

local Protocol = table.freeze({
	RegisterJob = "ParallelActors_RegisterJob",
	SetSharedMemory = "ParallelActors_SetSharedMemory",
	SetWorkerPayload = "ParallelActors_SetWorkerPayload",
	RunManager = "ParallelActors_RunManager",
	RunShard = "ParallelActors_RunShard",
})

return Protocol
