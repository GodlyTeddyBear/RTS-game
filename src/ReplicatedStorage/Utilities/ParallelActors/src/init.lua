--!strict

local Types = require(script.Types)
local Workplace = require(script.Workplace)

export type TRunStatus = Types.TRunStatus
export type TRunRequest = Types.TRunRequest
export type TRunError = Types.TRunError
export type TShardCompletion = Types.TShardCompletion
export type TRunSnapshot = Types.TRunSnapshot
export type TRunResult = Types.TRunResult
export type TRunHandle = Types.TRunHandle
export type TJobExecutor = Types.TJobExecutor
export type TWorkplaceConfig = Types.TWorkplaceConfig
export type TWorkplace = Types.TWorkplace

local ParallelActors = {}

function ParallelActors.new(config: Types.TWorkplaceConfig): Types.TWorkplace
	return Workplace.new(config)
end

ParallelActors.Workplace = Workplace

return table.freeze(ParallelActors)
