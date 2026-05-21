--!strict

local ParallelActors = require(script.src)

export type TRunStatus = ParallelActors.TRunStatus
export type TRunRequest = ParallelActors.TRunRequest
export type TRunError = ParallelActors.TRunError
export type TShardCompletion = ParallelActors.TShardCompletion
export type TRunSnapshot = ParallelActors.TRunSnapshot
export type TRunResult = ParallelActors.TRunResult
export type TRunHandle = ParallelActors.TRunHandle
export type TJobExecutor = ParallelActors.TJobExecutor
export type TWorkplaceConfig = ParallelActors.TWorkplaceConfig
export type TWorkplace = ParallelActors.TWorkplace

return ParallelActors
