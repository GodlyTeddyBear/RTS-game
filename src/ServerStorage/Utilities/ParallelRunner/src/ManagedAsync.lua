--!strict

local Types = require(script.Parent.Types)

type TManagedAsyncResult = Types.TManagedAsyncResult
type TManagedAsyncState = Types.TManagedAsyncState
type TManagedCompletionStatus = Types.TManagedCompletionStatus
type TManagedConsumeStatus = Types.TManagedConsumeStatus
type TManagedDispatchStatus = Types.TManagedDispatchStatus

local ManagedAsync = {}

local function _ResolveClock(nowClock: number?): number
	if type(nowClock) == "number" then
		return nowClock
	end

	return os.clock()
end

function ManagedAsync.CreateState(): TManagedAsyncState
	return {
		PendingRequestId = 0,
		LatestAppliedRequestId = 0,
		LatestCompletedResult = nil,
		InFlight = false,
		InFlightRequestId = nil,
		InFlightSessionToken = nil,
		LastDispatchClock = 0,
	}
end

function ManagedAsync.ResetState(state: TManagedAsyncState)
	state.PendingRequestId = 0
	state.LatestAppliedRequestId = 0
	state.LatestCompletedResult = nil
	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionToken = nil
	state.LastDispatchClock = 0
end

function ManagedAsync.ExpireInFlightRequest(
	state: TManagedAsyncState,
	maxInFlightSeconds: number,
	nowClock: number?
): boolean
	if not state.InFlight then
		return false
	end
	if type(maxInFlightSeconds) ~= "number" or maxInFlightSeconds <= 0 then
		return false
	end

	local elapsedSeconds = _ResolveClock(nowClock) - state.LastDispatchClock
	if elapsedSeconds <= maxInFlightSeconds then
		return false
	end

	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionToken = nil
	return true
end

function ManagedAsync.HasInFlightRequest(
	state: TManagedAsyncState,
	maxInFlightSeconds: number?,
	nowClock: number?
): boolean
	if type(maxInFlightSeconds) == "number" and maxInFlightSeconds > 0 then
		ManagedAsync.ExpireInFlightRequest(state, maxInFlightSeconds, nowClock)
	end

	return state.InFlight
end

function ManagedAsync.BeginRequest(
	state: TManagedAsyncState,
	sessionToken: any?,
	nowClock: number?,
	maxInFlightSeconds: number?
): (TManagedDispatchStatus, number?)
	if ManagedAsync.HasInFlightRequest(state, maxInFlightSeconds, nowClock) then
		return "InFlight", nil
	end

	local requestId = state.PendingRequestId + 1
	state.PendingRequestId = requestId
	state.InFlight = true
	state.InFlightRequestId = requestId
	state.InFlightSessionToken = sessionToken
	state.LastDispatchClock = _ResolveClock(nowClock)
	return "Dispatched", requestId
end

function ManagedAsync.CompleteRequest(
	state: TManagedAsyncState,
	result: TManagedAsyncResult
): TManagedCompletionStatus
	if state.InFlightRequestId ~= result.RequestId then
		return "StaleRequest"
	end

	local status: TManagedCompletionStatus = "Accepted"
	if state.LatestCompletedResult ~= nil then
		status = "ReplacedPrevious"
	end

	state.InFlight = false
	state.InFlightRequestId = nil
	state.InFlightSessionToken = nil
	state.LatestCompletedResult = result
	return status
end

function ManagedAsync.ConsumeLatestResult(
	state: TManagedAsyncState,
	currentSessionToken: any?
): (TManagedAsyncResult?, TManagedConsumeStatus)
	local result = state.LatestCompletedResult
	if result == nil then
		return nil, "NoResult"
	end

	state.LatestCompletedResult = nil
	if result.RequestId <= state.LatestAppliedRequestId then
		return nil, "StaleRequest"
	end

	if result.SessionToken ~= nil and currentSessionToken ~= nil and result.SessionToken ~= currentSessionToken then
		return nil, "SessionMismatch"
	end

	state.LatestAppliedRequestId = result.RequestId
	return result, "Accepted"
end

return table.freeze(ManagedAsync)
