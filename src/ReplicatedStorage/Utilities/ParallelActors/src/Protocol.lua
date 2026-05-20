--!strict

local Protocol = table.freeze({
	RegisterJob = "ParallelActors_RegisterJob",
	SetSharedMemory = "ParallelActors_SetSharedMemory",
	RunShard = "ParallelActors_RunShard",
})

return Protocol
