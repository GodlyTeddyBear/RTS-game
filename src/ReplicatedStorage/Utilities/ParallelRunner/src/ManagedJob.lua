--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local SharedPlus = require(ReplicatedStorage.Utilities.SharedPlus)

local ManagedAsync = require(script.Parent.ManagedAsync)
local ManagedJobPolicies = require(script.Parent.ManagedJobPolicies)
local Types = require(script.Parent.Types)
local Validation = require(script.Parent.Validation)

type TResult<T> = Types.TResult<T>
type TManagedAsyncResult = Types.TManagedAsyncResult
type TManagedJob = Types.TManagedJob
type TManagedJobConfig = Types.TManagedJobConfig
type TManagedJobDispatchStatus = Types.TManagedJobDispatchStatus
type TManagedJobResult = Types.TManagedJobResult
type TManagedJobStatus = Types.TManagedJobStatus
type TRunner = Types.TRunner
type TRunOutput = Types.TRunOutput
type TRunnerRunHandle = Types.TRunnerRunHandle
type TSharedCompiledHandle = Types.TSharedCompiledHandle
type TSharedPacket = Types.TSharedPacket

local ManagedJob = {}
ManagedJob.__index = ManagedJob

local function _BuildManagedError(errType: string, message: string, data: { [string]: any }?): TResult<TRunOutput>
	return Result.Err(errType, message, data)
end

local function _BuildTimeoutError(jobName: string, timeoutSeconds: number): TResult<TRunOutput>
	return _BuildManagedError(
		"ParallelRunnerManagedJobTimeout",
		`ParallelRunner managed job "{jobName}" timed out after {timeoutSeconds} seconds`,
		{
			JobName = jobName,
			TimeoutSeconds = timeoutSeconds,
		}
	)
end

local function _CompleteManagedRequest(
	self,
	requestId: number,
	sessionToken: any?,
	payload: any,
	rows: { { [string]: any } }?,
	err: TResult<TRunOutput>?
)
	local completionStatus = ManagedAsync.CompleteRequest(self._state, {
		RequestId = requestId,
		SessionToken = sessionToken,
		Payload = payload,
		Rows = rows,
		Err = err,
		CompletedClock = os.clock(),
	} :: TManagedAsyncResult)

	if completionStatus == "StaleRequest" then
		return
	end

	self._lastError = err
end

local function _WrapBuilderFailure(jobName: string, stage: string, payload: any, builderError: any): TResult<TRunOutput>
	return _BuildManagedError(
		"ParallelRunnerManagedJobBuildError",
		`ParallelRunner managed job "{jobName}" failed while building {stage}`,
		{
			JobName = jobName,
			Stage = stage,
			Payload = payload,
			Cause = builderError,
		}
	)
end

local function _WrapRunSetupFailure(jobName: string, payload: any, runError: TResult<TRunnerRunHandle>): TResult<TRunOutput>
	return _BuildManagedError(
		"ParallelRunnerManagedJobDispatchError",
		`ParallelRunner managed job "{jobName}" failed to dispatch`,
		{
			JobName = jobName,
			Payload = payload,
			Cause = runError,
		}
	)
end

local function _WrapPromiseRejected(jobName: string, payload: any, promiseError: any): TResult<TRunOutput>
	return _BuildManagedError(
		"ParallelRunnerManagedJobPromiseRejected",
		`ParallelRunner managed job "{jobName}" completion promise rejected unexpectedly`,
		{
			JobName = jobName,
			Payload = payload,
			Cause = promiseError,
		}
	)
end

function ManagedJob.new(runner: TRunner, config: TManagedJobConfig): TManagedJob
	Validation.AssertManagedJobConfig((runner :: any), config :: any)
	local registeredJob = (runner :: any)._registeredJobs[config.JobName]
	local sharedSchema = registeredJob.Job:GetSchemas().Shared
	assert(sharedSchema ~= nil, `ParallelRunner:CreateManagedJob("{config.JobName}") requires SharedSchema`)

	local self = setmetatable({}, ManagedJob)
	self._runner = runner
	self._config = config
	self._policyPreset = ManagedJobPolicies.Resolve(config.Policy)
	self._state = ManagedAsync.CreateState()
	self._sharedMemoryHandle = SharedPlus.Compiler.Compile(sharedSchema).new() :: TSharedCompiledHandle
	self._lastError = nil
	self._destroyed = false

	(runner :: any)._managedJobs[self] = true
	return self :: any
end

function ManagedJob:_ExpireInFlightIfNeeded()
	local timeoutSeconds = self._config.MaxInFlightSeconds
	if type(timeoutSeconds) ~= "number" or timeoutSeconds <= 0 then
		return
	end

	local didExpire = ManagedAsync.ExpireInFlightRequest(self._state, timeoutSeconds)
	if not didExpire then
		return
	end

	self._lastError = _BuildTimeoutError(self._config.JobName, timeoutSeconds)
end

function ManagedJob:Dispatch(payload: any): TManagedJobDispatchStatus
	assert(not self._destroyed, "ParallelRunner managed job has already been destroyed")
	self:_ExpireInFlightIfNeeded()
	if ManagedAsync.HasInFlightRequest(self._state, self._config.MaxInFlightSeconds) then
		return "InFlight"
	end

	local sessionToken = nil
	if self._config.GetSessionToken ~= nil then
		local ok, sessionOrError = pcall(self._config.GetSessionToken, payload)
		if not ok then
			local dispatchStatus, requestId = ManagedAsync.BeginRequest(
				self._state,
				nil,
				nil,
				self._config.MaxInFlightSeconds
			)
			if dispatchStatus == "InFlight" then
				return dispatchStatus
			end

			_CompleteManagedRequest(
				self,
				requestId :: number,
				nil,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "session token", payload, sessionOrError)
			)
			return "Dispatched"
		end

		sessionToken = sessionOrError
	end

	local dispatchStatus, requestId = ManagedAsync.BeginRequest(
		self._state,
		sessionToken,
		nil,
		self._config.MaxInFlightSeconds
	)
	if dispatchStatus == "InFlight" then
		return dispatchStatus
	end

	local sharedPacket = nil :: TSharedPacket?
	do
		local ok, sharedPacketOrError = pcall(self._config.BuildSharedMemory, payload)
		if not ok then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "shared memory", payload, sharedPacketOrError)
			)
			return "Dispatched"
		end

		sharedPacket = sharedPacketOrError
	end

	local okSharedPacket, sharedPacketValidationError = pcall(function()
		Validation.AssertManagedSharedPacket(self._config.JobName, sharedPacket)
	end)
	if not okSharedPacket then
		_CompleteManagedRequest(
			self,
			requestId :: number,
			sessionToken,
			payload,
			nil,
			_WrapBuilderFailure(self._config.JobName, "shared memory packet", payload, sharedPacketValidationError)
		)
		return "Dispatched"
	end

	local sharedMemory = nil
	do
		local ok, sharedMemoryOrError = pcall(function()
			local sharedMemoryHandle = self._sharedMemoryHandle :: TSharedCompiledHandle
			sharedMemoryHandle:BeginWrite()
			sharedMemoryHandle:WritePacket(sharedPacket :: TSharedPacket)
			return sharedMemoryHandle:Finalize()
		end)
		if not ok then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_BuildManagedError(
					"ParallelRunnerManagedJobSharedPacketError",
					`ParallelRunner managed job "{self._config.JobName}" failed to apply shared memory packet`,
					{
						JobName = self._config.JobName,
						Payload = payload,
						Cause = sharedMemoryOrError,
					}
				)
			)
			return "Dispatched"
		end

		sharedMemory = sharedMemoryOrError
	end

	local runRequest = nil
	do
		local ok, runRequestOrError = pcall(self._config.BuildRunRequest, payload)
		if not ok then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "run request", payload, runRequestOrError)
			)
			return "Dispatched"
		end

		runRequest = runRequestOrError
	end

	local okRunRequest, runRequestValidationError = pcall(function()
		Validation.AssertManagedRunRequest(self._config.JobName, runRequest)
	end)
	if not okRunRequest then
		_CompleteManagedRequest(
			self,
			requestId :: number,
			sessionToken,
			payload,
			nil,
			_WrapBuilderFailure(self._config.JobName, "run request", payload, runRequestValidationError)
		)
		return "Dispatched"
	end

	local runResult = self._runner:Run({
		JobName = self._config.JobName,
		Args = runRequest.Args,
		LogicalWorkCount = runRequest.LogicalWorkCount,
		BatchSize = runRequest.BatchSize,
		SharedMemory = sharedMemory,
	})
	if not runResult.success then
		_CompleteManagedRequest(
			self,
			requestId :: number,
			sessionToken,
			payload,
			nil,
			_WrapRunSetupFailure(self._config.JobName, payload, runResult)
		)
		return "Dispatched"
	end

	local handle = runResult.value
	handle:GetPromise()
		:andThen(function(result: TResult<TRunOutput>)
			if self._destroyed then
				return
			end

			local rows = nil
			local err = nil
			if result.success then
				rows = result.value.Rows
			else
				err = result
			end

			_CompleteManagedRequest(self, requestId :: number, sessionToken, payload, rows, err)
		end)
		:catch(function(promiseError)
			if self._destroyed then
				return
			end

			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapPromiseRejected(self._config.JobName, payload, promiseError)
			)
		end)

	return "Dispatched"
end

function ManagedJob:PollCompleted(currentSessionToken: any?): TManagedJobResult?
	assert(not self._destroyed, "ParallelRunner managed job has already been destroyed")
	self:_ExpireInFlightIfNeeded()

	local result, consumeStatus = ManagedAsync.ConsumeLatestResult(self._state, currentSessionToken)
	if consumeStatus ~= "Accepted" or result == nil then
		return nil
	end

	return {
		RequestId = result.RequestId,
		SessionToken = result.SessionToken,
		Payload = result.Payload,
		Rows = result.Rows,
		Err = result.Err,
		CompletedClock = result.CompletedClock,
		PolicyStatus = "Fresh",
	}
end

function ManagedJob:HasInFlight(): boolean
	assert(not self._destroyed, "ParallelRunner managed job has already been destroyed")
	self:_ExpireInFlightIfNeeded()
	return ManagedAsync.HasInFlightRequest(self._state, self._config.MaxInFlightSeconds)
end

function ManagedJob:GetStatus(): TManagedJobStatus
	assert(not self._destroyed, "ParallelRunner managed job has already been destroyed")
	self:_ExpireInFlightIfNeeded()

	return {
		InFlight = self:HasInFlight(),
		LastDispatchClock = self._state.LastDispatchClock,
		HasCompletedResult = self._state.LatestCompletedResult ~= nil,
		PolicyPreset = self._policyPreset,
		LastError = self._lastError,
	}
end

function ManagedJob:Reset()
	assert(not self._destroyed, "ParallelRunner managed job has already been destroyed")
	ManagedAsync.ResetState(self._state)
	self._lastError = nil
end

function ManagedJob:Destroy()
	if self._destroyed then
		return
	end

	local runner = self._runner :: any
	self._destroyed = true
	ManagedAsync.ResetState(self._state)
	self._lastError = nil
	self._sharedMemoryHandle:Destroy()
	runner._managedJobs[self] = nil
	self._runner = nil
end

return table.freeze(ManagedJob)
