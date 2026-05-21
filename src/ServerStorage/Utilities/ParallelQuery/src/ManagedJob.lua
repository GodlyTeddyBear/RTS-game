--!strict

local ManagedAsync = require(script.Parent.ManagedAsync)
local ManagedJobPolicies = require(script.Parent.ManagedJobPolicies)
local Profiling = require(script.Parent.Profiling)
local Types = require(script.Parent.Types)

type TManagedAsyncResult = Types.TManagedAsyncResult
type TManagedAsyncState = Types.TManagedAsyncState
type TManagedJob = Types.TManagedJob
type TManagedJobConfig = Types.TManagedJobConfig
type TManagedJobDispatchStatus = Types.TManagedJobDispatchStatus
type TManagedJobPolicyPreset = Types.TManagedJobPolicyPreset
type TManagedJobResult = Types.TManagedJobResult
type TManagedJobStatus = Types.TManagedJobStatus
type TParallelQueryRunner = Types.TParallelQueryRunner

local ManagedJob = {}
ManagedJob.__index = ManagedJob

local function _ClearInFlightState(state: TManagedAsyncState)
	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionToken = nil
end

local function _InvalidatePendingCompletions(state: TManagedAsyncState)
	state.LatestAppliedRequestId = state.PendingRequestId
	state.LatestCompletedResult = nil
	state.LastDispatchClock = 0
	_ClearInFlightState(state)
end

local function _BuildTimeoutError(operationName: string, timeoutSeconds: number): Types.TParallelQueryError
	return {
		Kind = "Timeout",
		OperationName = operationName,
		Message = `ParallelQuery operation "{operationName}" timed out after {timeoutSeconds} seconds`,
		TimeoutSeconds = timeoutSeconds,
	}
end

local function _MatchesSessionToken(result: TManagedAsyncResult?, currentSessionToken: any?): boolean
	if result == nil then
		return false
	end
	if result.SessionToken ~= nil and currentSessionToken ~= nil and result.SessionToken ~= currentSessionToken then
		return false
	end
	return true
end

local function _BuildJobResult(
	result: TManagedAsyncResult,
	policyStatus: "Fresh" | "Fallback",
	fallbackReason: "PreviousGood" | "Error" | "Timeout"?
): TManagedJobResult
	return {
		RequestId = result.RequestId,
		SessionToken = result.SessionToken,
		Payload = result.Payload,
		Rows = result.Rows,
		Err = result.Err,
		CompletedClock = result.CompletedClock,
		PolicyStatus = policyStatus,
		FallbackReason = fallbackReason,
	}
end

local function _BuildFallbackFromPreviousGood(
	lastGoodResult: TManagedJobResult,
	fallbackReason: "PreviousGood" | "Error" | "Timeout"
): TManagedJobResult
	return {
		RequestId = lastGoodResult.RequestId,
		SessionToken = lastGoodResult.SessionToken,
		Payload = lastGoodResult.Payload,
		Rows = lastGoodResult.Rows,
		Err = nil,
		CompletedClock = os.clock(),
		PolicyStatus = "Fallback",
		FallbackReason = fallbackReason,
	}
end

local function _BuildFallbackMarker(
	state: TManagedAsyncState,
	err: any,
	fallbackReason: "PreviousGood" | "Error" | "Timeout"
): TManagedJobResult
	return {
		RequestId = state.PendingRequestId,
		SessionToken = nil,
		Payload = nil,
		Rows = nil,
		Err = err,
		CompletedClock = os.clock(),
		PolicyStatus = "Fallback",
		FallbackReason = fallbackReason,
	}
end

function ManagedJob.new(runner: TParallelQueryRunner, config: TManagedJobConfig): TManagedJob
	assert(type(config) == "table", "ParallelQuery:CreateManagedJob requires a config table")
	assert(type(config.OperationName) == "string" and config.OperationName ~= "", "Managed job requires OperationName")
	assert(type(config.BuildLocalMemory) == "function", "Managed job requires BuildLocalMemory")
	assert(type(config.BuildRunRequest) == "function", "Managed job requires BuildRunRequest")
	if config.GetSessionToken ~= nil then
		assert(type(config.GetSessionToken) == "function", "Managed job GetSessionToken must be a function when provided")
	end
	if config.MaxInFlightSeconds ~= nil then
		assert(type(config.MaxInFlightSeconds) == "number" and config.MaxInFlightSeconds > 0, "Managed job MaxInFlightSeconds must be a positive number")
	end

	assert(
		runner._operations[config.OperationName] ~= nil,
		`ParallelQuery:CreateManagedJob("{config.OperationName}") requires a registered operation`
	)

	local self = setmetatable({}, ManagedJob)
	self._runner = runner
	self._config = config
	self._policyPreset = ManagedJobPolicies.Resolve(config.Policy)
	self._state = ManagedAsync.CreateState()
	self._destroyed = false
	self._lastError = nil
	self._lastGoodResult = nil
	self._pendingFallbackResult = nil
	self._pendingFallbackReason = nil
	self._profile = Profiling.CreateJobProfile(config.OperationName)

	runner._managedJobs[self] = true
	return self :: any
end

function ManagedJob:_QueueFallbackResult(
	fallbackReason: "PreviousGood" | "Error" | "Timeout",
	err: any?,
	currentSessionToken: any?
)
	if self._policyPreset == ManagedJobPolicies.StrictFreshOnly then
		return
	end

	if self._policyPreset == ManagedJobPolicies.KeepLastGood then
		if _MatchesSessionToken(self._lastGoodResult, currentSessionToken) then
			self._pendingFallbackResult = _BuildFallbackFromPreviousGood(self._lastGoodResult, fallbackReason)
			self._pendingFallbackReason = fallbackReason
			return
		end
	end

	if self._policyPreset == ManagedJobPolicies.ApplyFreshOrMarkFallback then
		self._pendingFallbackResult = _BuildFallbackMarker(self._state, err, fallbackReason)
		self._pendingFallbackReason = fallbackReason
	end
end

function ManagedJob:_ExpireInFlightIfNeeded(currentSessionToken: any?)
	local timeoutSeconds = self._config.MaxInFlightSeconds
	if type(timeoutSeconds) ~= "number" or timeoutSeconds <= 0 then
		return
	end

	local didExpire = ManagedAsync.ExpireInFlightRequest(self._state, timeoutSeconds)
	if not didExpire then
		return
	end

	local timeoutError = _BuildTimeoutError(self._config.OperationName, timeoutSeconds)
	self._lastError = timeoutError
	self:_QueueFallbackResult("Timeout", timeoutError, currentSessionToken)
end

function ManagedJob:Dispatch(payload: any): TManagedJobDispatchStatus
	assert(not self._destroyed, "Managed job has already been destroyed")
	local closeDispatchProfile = Profiling.BeginJobScope(self._profile, "Dispatch")
	self:_ExpireInFlightIfNeeded(nil)

	local sessionToken = if self._config.GetSessionToken ~= nil then self._config.GetSessionToken(payload) else nil
	local dispatchStatus, requestId = ManagedAsync.BeginRequest(
		self._state,
		sessionToken,
		nil,
		self._config.MaxInFlightSeconds
	)
	if dispatchStatus == "InFlight" then
		closeDispatchProfile()
		return dispatchStatus
	end

	local localMemory = self._config.BuildLocalMemory(payload)
	local runRequest = self._config.BuildRunRequest(payload)
	local promise: typeof(self._runner:RunAsync(self._config.OperationName, runRequest))? = nil

	local ok, err = pcall(function()
		self._runner:SetLocalMemory(self._config.OperationName, localMemory)
		promise = self._runner:RunAsync(self._config.OperationName, runRequest)
	end)
	if not ok or promise == nil then
		_ClearInFlightState(self._state)
		closeDispatchProfile()
		error(err, 0)
	end

	closeDispatchProfile()

	promise:andThen(function(rows)
		if self._destroyed then
			return
		end

		local closeCompleteProfile = Profiling.BeginJobScope(self._profile, "Complete")

		local completionStatus = ManagedAsync.CompleteRequest(self._state, {
			RequestId = requestId :: number,
			SessionToken = sessionToken,
			Payload = payload,
			Rows = rows :: any,
			Err = nil,
			CompletedClock = os.clock(),
		})
		if completionStatus ~= "StaleRequest" then
			self._lastError = nil
			self._pendingFallbackReason = nil
		end
		closeCompleteProfile()
	end):catch(function(runErr)
		if self._destroyed then
			return
		end

		local closeErrorProfile = Profiling.BeginJobScope(self._profile, "Error")

		local completionStatus = ManagedAsync.CompleteRequest(self._state, {
			RequestId = requestId :: number,
			SessionToken = sessionToken,
			Payload = payload,
			Rows = nil,
			Err = runErr,
			CompletedClock = os.clock(),
		})
		if completionStatus ~= "StaleRequest" then
			self._lastError = runErr
		end
		closeErrorProfile()
	end)

	return "Dispatched"
end

function ManagedJob:PollCompleted(currentSessionToken: any?): TManagedJobResult?
	assert(not self._destroyed, "Managed job has already been destroyed")
	local closePollProfile = Profiling.BeginJobScope(self._profile, "PollCompleted")
	self:_ExpireInFlightIfNeeded(currentSessionToken)

	if self._pendingFallbackResult ~= nil then
		local fallbackResult = self._pendingFallbackResult
		self._pendingFallbackResult = nil
		self._pendingFallbackReason = nil
		closePollProfile()
		return fallbackResult
	end

	local result, consumeStatus = ManagedAsync.ConsumeLatestResult(self._state, currentSessionToken)
	if consumeStatus ~= "Accepted" then
		closePollProfile()
		return nil
	end

	if result.Err == nil then
		local freshResult = _BuildJobResult(result, "Fresh", nil)
		self._lastGoodResult = freshResult
		self._pendingFallbackReason = nil
		closePollProfile()
		return freshResult
	end

	if self._policyPreset == ManagedJobPolicies.KeepLastGood then
		if _MatchesSessionToken(self._lastGoodResult, currentSessionToken) then
			local fallbackResult = _BuildFallbackFromPreviousGood(self._lastGoodResult, "Error")
			self._pendingFallbackReason = nil
			closePollProfile()
			return fallbackResult
		end
	end

	if self._policyPreset == ManagedJobPolicies.ApplyFreshOrMarkFallback then
		self._pendingFallbackReason = nil
		closePollProfile()
		return _BuildFallbackMarker(self._state, result.Err, "Error")
	end

	self._pendingFallbackReason = nil
	local jobResult = _BuildJobResult(result, "Fresh", nil)
	closePollProfile()
	return jobResult
end

function ManagedJob:HasInFlight(): boolean
	assert(not self._destroyed, "Managed job has already been destroyed")
	self:_ExpireInFlightIfNeeded(nil)
	return ManagedAsync.HasInFlightRequest(self._state, self._config.MaxInFlightSeconds)
end

function ManagedJob:GetStatus(): TManagedJobStatus
	assert(not self._destroyed, "Managed job has already been destroyed")
	self:_ExpireInFlightIfNeeded(nil)

	return {
		InFlight = self:HasInFlight(),
		LastDispatchClock = self._state.LastDispatchClock,
		HasCompletedResult = self._state.LatestCompletedResult ~= nil,
		HasLastGoodResult = self._lastGoodResult ~= nil,
		NeedsFallback = self._pendingFallbackResult ~= nil,
		FallbackReason = self._pendingFallbackReason,
		PolicyPreset = self._policyPreset,
		LastError = self._lastError,
	}
end

function ManagedJob:GetProfileSnapshot()
	assert(not self._destroyed, "Managed job has already been destroyed")
	return Profiling.GetJobSnapshot(self._profile)
end

function ManagedJob:Reset()
	assert(not self._destroyed, "Managed job has already been destroyed")

	_InvalidatePendingCompletions(self._state)
	self._lastError = nil
	self._lastGoodResult = nil
	self._pendingFallbackResult = nil
	self._pendingFallbackReason = nil
end

function ManagedJob:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	_InvalidatePendingCompletions(self._state)
	self._runner._managedJobs[self] = nil
	self._lastError = nil
	self._lastGoodResult = nil
	self._pendingFallbackResult = nil
	self._pendingFallbackReason = nil
	self._runner = nil
end

return table.freeze(ManagedJob)
