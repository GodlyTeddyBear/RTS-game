--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GoodSignal = require(ReplicatedStorage.Packages.Goodsignal)
local Result = require(ReplicatedStorage.Utilities.Result)
local Types = require(script.Parent.Types)

type TCompletedSignal = Types.TCompletedSignal
type TResult<T> = Types.TResult<T>
type TRunOutput = Types.TRunOutput
type TRunPromise = Types.TRunPromise
type TRunnerRunHandle = Types.TRunnerRunHandle
type TWorkplaceRunHandle = Types.TWorkplaceRunHandle

local RunHandle = {}
RunHandle.__index = RunHandle

local function _ReifyResult<T>(resultLike: any): TResult<T>
	if resultLike.success then
		return Result.Ok(resultLike.value)
	end

	return Result.Err(resultLike.type, resultLike.message, resultLike.data)
end

local function _BuildPromiseRejectedResult(jobName: string, runId: number, promiseError: any): TResult<TRunOutput>
	return Result.Err("ParallelRunnerPromiseRejected", `ParallelRunner run "{jobName}" promise rejected unexpectedly`, {
		JobName = jobName,
		RunId = runId,
		Cause = promiseError,
	})
end

local function _ResolveCompletionResult(self): TResult<TRunOutput>
	local ok, result = self._completionPromise:await()
	if not ok then
		return _BuildPromiseRejectedResult(self:GetJobName(), self:GetRunId(), result)
	end

	return _ReifyResult(result)
end

local function _FireCompletedOnce(self)
	if self._completedSignalFired then
		return
	end

	self._completedSignalFired = true
	self.Completed:Fire(_ResolveCompletionResult(self))
end

function RunHandle.new(workplaceRunHandle: TWorkplaceRunHandle, completionPromise: TRunPromise): TRunnerRunHandle
	local self = setmetatable({}, RunHandle)
	self._workplaceRunHandle = workplaceRunHandle
	self._completionPromise = completionPromise
	self._completedSignalFired = false
	self.Completed = GoodSignal.new() :: TCompletedSignal

	completionPromise
		:andThen(function()
			_FireCompletedOnce(self)
		end)
		:catch(function()
			_FireCompletedOnce(self)
		end)

	return self :: any
end

function RunHandle:GetRunId(): number
	return self._workplaceRunHandle:GetRunId()
end

function RunHandle:GetJobName(): string
	return self._workplaceRunHandle:GetJobName()
end

function RunHandle:GetStatus()
	return self._workplaceRunHandle:GetStatus()
end

function RunHandle:IsQueued(): boolean
	return self._workplaceRunHandle:IsQueued()
end

function RunHandle:IsRunning(): boolean
	return self._workplaceRunHandle:IsRunning()
end

function RunHandle:IsCompleted(): boolean
	return self._workplaceRunHandle:IsCompleted()
end

function RunHandle:IsFailed(): boolean
	return self._workplaceRunHandle:IsFailed()
end

function RunHandle:IsCancelled(): boolean
	return self._workplaceRunHandle:IsCancelled()
end

function RunHandle:IsDone(): boolean
	return self._workplaceRunHandle:IsDone()
end

function RunHandle:GetSnapshot()
	return self._workplaceRunHandle:GetSnapshot()
end

function RunHandle:GetPromise(): TRunPromise
	return self._completionPromise
end

function RunHandle:Await(): TResult<TRunOutput>
	return _ResolveCompletionResult(self)
end

function RunHandle:Cancel(): boolean
	return self._workplaceRunHandle:Cancel()
end

return table.freeze(RunHandle)
