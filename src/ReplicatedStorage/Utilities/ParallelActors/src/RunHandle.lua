--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Promise)
local Types = require(script.Parent.Types)

type TRunHandle = Types.TRunHandle
type TRunRecord = Types.TRunRecord
type TRunResult = Types.TRunResult
type TRunSnapshot = Types.TRunSnapshot
type TWorkplace = Types.TWorkplace

local TERMINAL_STATUSES = {
	Completed = true,
	Failed = true,
	Cancelled = true,
}

local RunHandle = {}
RunHandle.__index = RunHandle

local function _CloneError(runError)
	if runError == nil then
		return nil
	end

	return table.freeze({
		JobName = runError.JobName,
		ShardIndex = runError.ShardIndex,
		StartTaskId = runError.StartTaskId,
		Message = runError.Message,
		Traceback = runError.Traceback,
	})
end

function RunHandle.new(workplace: TWorkplace, runRecord: TRunRecord): TRunHandle
	local self = setmetatable({}, RunHandle)
	self._workplace = workplace
	self._runRecord = runRecord
	return self :: any
end

function RunHandle:GetRunId(): number
	return self._runRecord.RunId
end

function RunHandle:GetJobName(): string
	return self._runRecord.JobName
end

function RunHandle:GetStatus()
	return self._runRecord.Status
end

function RunHandle:IsQueued(): boolean
	return self:GetStatus() == "Queued"
end

function RunHandle:IsRunning(): boolean
	return self:GetStatus() == "Running"
end

function RunHandle:IsCompleted(): boolean
	return self:GetStatus() == "Completed"
end

function RunHandle:IsFailed(): boolean
	return self:GetStatus() == "Failed"
end

function RunHandle:IsCancelled(): boolean
	return self:GetStatus() == "Cancelled"
end

function RunHandle:IsDone(): boolean
	return TERMINAL_STATUSES[self:GetStatus()] == true
end

function RunHandle:GetPromise(): typeof(Promise.new(function() end))
	return self._runRecord.Promise
end

function RunHandle:Await(): TRunResult
	local ok, result = self._runRecord.Promise:await()
	if not ok then
		error(result, 2)
	end

	return result
end

function RunHandle:Cancel(): boolean
	return (self._workplace :: any):_CancelRun(self._runRecord.RunId)
end

function RunHandle:GetSnapshot(): TRunSnapshot
	return table.freeze({
		RunId = self._runRecord.RunId,
		JobName = self._runRecord.JobName,
		Status = self._runRecord.Status,
		LogicalWorkCount = self._runRecord.LogicalWorkCount,
		BatchSize = self._runRecord.BatchSize,
		ShardCount = self._runRecord.ShardCount,
		QueuedShardCount = self._runRecord.QueuedShardCount,
		ActiveShardCount = self._runRecord.ActiveShardCount,
		CompletedShardCount = self._runRecord.CompletedShardCount,
		FirstError = _CloneError(self._runRecord.FirstError),
	})
end

function RunHandle:GetLogicalWorkCount(): number
	return self._runRecord.LogicalWorkCount
end

function RunHandle:GetBatchSize(): number
	return self._runRecord.BatchSize
end

function RunHandle:GetShardCount(): number
	return self._runRecord.ShardCount
end

function RunHandle:GetQueuedShardCount(): number
	return self._runRecord.QueuedShardCount
end

function RunHandle:GetActiveShardCount(): number
	return self._runRecord.ActiveShardCount
end

function RunHandle:GetCompletedShardCount(): number
	return self._runRecord.CompletedShardCount
end

return table.freeze(RunHandle)
