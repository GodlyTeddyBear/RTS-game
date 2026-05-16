--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)

type TRunnerProfile = {
	Name: string,
	Enabled: boolean,
}

type TJobProfile = {
	OperationName: string,
	Enabled: boolean,
}

local Profiling = {}

local function _IsEnabled(): boolean
	return DebugConfig.ENABLED == true and DebugConfig.PARALLEL_QUERY_PROFILING == true
end

local function _BuildRunnerLabel(runnerProfile: TRunnerProfile?, operationName: string?, phaseName: string): string
	local runnerName = if runnerProfile ~= nil then runnerProfile.Name else "Runner"
	if operationName ~= nil then
		return `ParallelQuery.{runnerName}.{operationName}.{phaseName}`
	end

	return `ParallelQuery.{runnerName}.{phaseName}`
end

local function _BuildJobLabel(jobProfile: TJobProfile?, phaseName: string): string
	local operationName = if jobProfile ~= nil then jobProfile.OperationName else "Job"
	return `ParallelQuery.ManagedJob.{operationName}.{phaseName}`
end

function Profiling.IsEnabled(): boolean
	return _IsEnabled()
end

function Profiling.CreateRunnerProfile(name: string): TRunnerProfile
	return {
		Name = name,
		Enabled = _IsEnabled(),
	}
end

function Profiling.CreateJobProfile(operationName: string): TJobProfile
	return {
		OperationName = operationName,
		Enabled = _IsEnabled(),
	}
end

function Profiling.BeginRunnerScope(runnerProfile: TRunnerProfile?, phaseName: string): () -> ()
	return DebugPlus.begin(_BuildRunnerLabel(runnerProfile, nil, phaseName), if runnerProfile ~= nil then runnerProfile.Enabled else false)
end

function Profiling.BeginOperationScope(
	runnerProfile: TRunnerProfile?,
	operationName: string,
	phaseName: string
): () -> ()
	return DebugPlus.begin(
		_BuildRunnerLabel(runnerProfile, operationName, phaseName),
		if runnerProfile ~= nil then runnerProfile.Enabled else false
	)
end

function Profiling.BeginJobScope(jobProfile: TJobProfile?, phaseName: string): () -> ()
	return DebugPlus.begin(_BuildJobLabel(jobProfile, phaseName), if jobProfile ~= nil then jobProfile.Enabled else false)
end

function Profiling.GetRunnerSnapshot(_runnerProfile: TRunnerProfile?): nil
	return nil
end

function Profiling.GetJobSnapshot(_jobProfile: TJobProfile?): nil
	return nil
end

function Profiling.EmitRunnerSummary(_runnerProfile: TRunnerProfile?, _force: boolean?)
	return
end

return table.freeze(Profiling)
