--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
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

local MANAGED_JOB_DISPATCH_APPLY_SHARED_MEMORY_PROFILE_ENABLED = DebugConfig.PARALLEL_RUNNER_PROFILING
local MANAGED_JOB_DISPATCH_APPLY_SHARED_MEMORY_PROFILE_TAG = "ParallelRunner:ManagedJob:Dispatch:ApplySharedMemory"
local MANAGED_JOB_DISPATCH_BEGIN_WRITE_PROFILE_TAG = "ParallelRunner:ManagedJob:Dispatch:ApplySharedMemory:BeginWrite"
local MANAGED_JOB_DISPATCH_WRITE_PACKET_PROFILE_TAG = "ParallelRunner:ManagedJob:Dispatch:ApplySharedMemory:WritePacket"
local MANAGED_JOB_DISPATCH_FINALIZE_PROFILE_TAG = "ParallelRunner:ManagedJob:Dispatch:ApplySharedMemory:Finalize"

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
	local completionStatus = ManagedAsync.CompleteRequest(
		self._state,
		{
			RequestId = requestId,
			SessionToken = sessionToken,
			Payload = payload,
			Rows = rows,
			Err = err,
			CompletedClock = os.clock(),
		} :: TManagedAsyncResult
	)

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

local function _WrapRunSetupFailure(
	jobName: string,
	payload: any,
	runError: TResult<TRunnerRunHandle>
): TResult<TRunOutput>
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
	Validation.AssertManagedJobConfig(runner :: any, config :: any)
	local registeredJob = (runner :: any)._registeredJobs[config.JobName]
	local sharedSchema = registeredJob.Job:GetSchemas().Shared

	local self = setmetatable({}, ManagedJob)
	self._runner = runner
	self._config = config
	self._policyPreset = ManagedJobPolicies.Resolve(config.Policy)
	self._state = ManagedAsync.CreateState()
	self._sharedMemoryHandle = if sharedSchema ~= nil
		and (type(config.BuildSharedMemory) == "function" or type(config.BuildBaseSharedMemory) == "function")
		then SharedPlus.Compiler.Compile(sharedSchema).new() :: TSharedCompiledHandle
		else nil
	self._payloadCodec = registeredJob.PayloadCodec
	self._lastError = nil
	self._destroyed = false

	(runner :: any)._managedJobs[self] = true
	return self :: any
end

local function _ShallowMergePayloadTables(
	basePayload: { [string]: any }?,
	overlayPayload: { [string]: any }?
): { [string]: any }?
	if basePayload == nil then
		return overlayPayload
	end
	if overlayPayload == nil then
		return basePayload
	end

	local mergedPayload = table.clone(basePayload)
	for key, value in overlayPayload do
		mergedPayload[key] = value
	end

	return mergedPayload
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
			local dispatchStatus, requestId =
				ManagedAsync.BeginRequest(self._state, nil, nil, self._config.MaxInFlightSeconds)
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

	local dispatchStatus, requestId =
		ManagedAsync.BeginRequest(self._state, sessionToken, nil, self._config.MaxInFlightSeconds)
	if dispatchStatus == "InFlight" then
		return dispatchStatus
	end

	local sharedPacket = nil :: TSharedPacket?
	if self._config.BuildSharedMemory ~= nil then
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

	local baseSharedPacket = nil :: TSharedPacket?
	if self._config.BuildBaseSharedMemory ~= nil then
		local ok, baseSharedPacketOrError = pcall(self._config.BuildBaseSharedMemory, payload)
		if not ok then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "base shared memory", payload, baseSharedPacketOrError)
			)
			return "Dispatched"
		end

		baseSharedPacket = baseSharedPacketOrError
	end

	if sharedPacket ~= nil then
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
	end

	if baseSharedPacket ~= nil then
		local okBaseSharedPacket, baseSharedPacketValidationError = pcall(function()
			Validation.AssertManagedBaseSharedPacket(self._config.JobName, baseSharedPacket)
		end)
		if not okBaseSharedPacket then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(
					self._config.JobName,
					"base shared memory packet",
					payload,
					baseSharedPacketValidationError
				)
			)
			return "Dispatched"
		end
	end

	local sharedMemory = nil
	if sharedPacket ~= nil or baseSharedPacket ~= nil then
		local closeApplySharedMemoryProfile = DebugPlus.begin(
			MANAGED_JOB_DISPATCH_APPLY_SHARED_MEMORY_PROFILE_TAG,
			MANAGED_JOB_DISPATCH_APPLY_SHARED_MEMORY_PROFILE_ENABLED
		)
		local ok, sharedMemoryOrError = pcall(function()
			local sharedMemoryHandle = self._sharedMemoryHandle :: TSharedCompiledHandle
			local closeBeginWriteProfile = DebugPlus.begin(
				MANAGED_JOB_DISPATCH_BEGIN_WRITE_PROFILE_TAG,
				--false
				MANAGED_JOB_DISPATCH_APPLY_SHARED_MEMORY_PROFILE_ENABLED
			)
			sharedMemoryHandle:BeginWrite()
			closeBeginWriteProfile()
			if sharedPacket ~= nil then
				local closeWritePacketProfile = DebugPlus.begin(
					MANAGED_JOB_DISPATCH_WRITE_PACKET_PROFILE_TAG,
					MANAGED_JOB_DISPATCH_APPLY_SHARED_MEMORY_PROFILE_ENABLED
				)
				sharedMemoryHandle:WritePacket(sharedPacket :: TSharedPacket)
				closeWritePacketProfile()
			end

			local closeFinalizeProfile = DebugPlus.begin(
				MANAGED_JOB_DISPATCH_FINALIZE_PROFILE_TAG,
				MANAGED_JOB_DISPATCH_APPLY_SHARED_MEMORY_PROFILE_ENABLED
			)
			local finalizedSharedMemory = sharedMemoryHandle:Finalize(baseSharedPacket)
			closeFinalizeProfile()
			return finalizedSharedMemory
		end)
		closeApplySharedMemoryProfile()
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

	local builtWorkerPayload = nil :: { [string]: any }?
	if self._config.BuildWorkerPayload ~= nil then
		local ok, workerPayloadOrError = pcall(self._config.BuildWorkerPayload, payload)
		if not ok then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "worker payload", payload, workerPayloadOrError)
			)
			return "Dispatched"
		end

		builtWorkerPayload = workerPayloadOrError
	end

	local baseWorkerPayload = nil :: { [string]: any }?
	if self._config.BuildBaseWorkerPayload ~= nil then
		local ok, baseWorkerPayloadOrError = pcall(self._config.BuildBaseWorkerPayload, payload)
		if not ok then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "base worker payload", payload, baseWorkerPayloadOrError)
			)
			return "Dispatched"
		end

		baseWorkerPayload = baseWorkerPayloadOrError
	end

	if builtWorkerPayload ~= nil then
		local okWorkerPayload, workerPayloadValidationError = pcall(function()
			Validation.AssertManagedWorkerPayload(self._config.JobName, builtWorkerPayload)
		end)
		if not okWorkerPayload then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "worker payload", payload, workerPayloadValidationError)
			)
			return "Dispatched"
		end
	end

	if baseWorkerPayload ~= nil then
		local okBaseWorkerPayload, baseWorkerPayloadValidationError = pcall(function()
			Validation.AssertManagedBaseWorkerPayload(self._config.JobName, baseWorkerPayload)
		end)
		if not okBaseWorkerPayload then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "base worker payload", payload, baseWorkerPayloadValidationError)
			)
			return "Dispatched"
		end
	end

	local resolvedWorkerPayload = _ShallowMergePayloadTables(baseWorkerPayload, builtWorkerPayload)

	local builtManagerPayload = nil :: { [string]: any }?
	if self._config.BuildManagerPayload ~= nil then
		local ok, managerPayloadOrError = pcall(self._config.BuildManagerPayload, payload)
		if not ok then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "manager payload", payload, managerPayloadOrError)
			)
			return "Dispatched"
		end

		builtManagerPayload = managerPayloadOrError
	end

	if builtManagerPayload ~= nil then
		local okManagerPayload, managerPayloadValidationError = pcall(function()
			Validation.AssertManagedManagerPayload(self._config.JobName, builtManagerPayload)
		end)
		if not okManagerPayload then
			_CompleteManagedRequest(
				self,
				requestId :: number,
				sessionToken,
				payload,
				nil,
				_WrapBuilderFailure(self._config.JobName, "manager payload", payload, managerPayloadValidationError)
			)
			return "Dispatched"
		end
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
		Validation.AssertManagedRunRequest(self._config.JobName, runRequest, builtManagerPayload ~= nil)
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
		WorkerPayload = resolvedWorkerPayload,
		ManagerPayload = builtManagerPayload,
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
	handle
		:GetPromise()
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
	if self._sharedMemoryHandle ~= nil then
		self._sharedMemoryHandle:Destroy()
	end
	runner._managedJobs[self] = nil
	self._runner = nil
end

return table.freeze(ManagedJob)
