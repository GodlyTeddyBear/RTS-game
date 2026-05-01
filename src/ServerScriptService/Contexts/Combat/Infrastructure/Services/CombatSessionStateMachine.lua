--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local StateMachine = require(ReplicatedStorage.Utilities.StateMachine)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

local Errors = require(script.Parent.Parent.Parent.Errors)

type CombatSessionState = CombatTypes.CombatSessionState
type CombatSessionLifecycleSnapshot = CombatTypes.CombatSessionLifecycleSnapshot

local LEGAL_TRANSITIONS: { [CombatSessionState | "Inactive"]: { [CombatSessionState | "Inactive"]: boolean } } = {
	Inactive = {
		Starting = true,
	},
	Starting = {
		RuntimeReady = true,
		Failed = true,
	},
	RuntimeReady = {
		Active = true,
		Failed = true,
	},
	Active = {
		Ending = true,
		Failed = true,
	},
	Ending = {
		Failed = true,
		Inactive = true,
	},
	Failed = {
		Inactive = true,
	},
}

type InternalCombatSessionState = CombatSessionState | "Inactive"

--[=[
	@class CombatSessionStateMachine
	Tracks one combat session lifecycle through the shared StateMachine utility.
	@server
]=]
local CombatSessionStateMachine = {}
CombatSessionStateMachine.__index = CombatSessionStateMachine

local function _RequireInvariant(failedInvariants: { string }, condition: boolean, invariantName: string)
	if condition then
		return
	end

	table.insert(failedInvariants, invariantName)
end

function CombatSessionStateMachine.new()
	local self = setmetatable({}, CombatSessionStateMachine)
	self._machine = StateMachine.new({
		InitialState = "Inactive" :: InternalCombatSessionState,
		Transitions = LEGAL_TRANSITIONS,
		ErrorType = "IllegalCombatSessionTransition",
		ErrorMessage = Errors.ILLEGAL_SESSION_TRANSITION,
		ErrorDataBuilder = function(fromState: InternalCombatSessionState, toState: InternalCombatSessionState)
			return {
				From = fromState,
				To = toState,
			}
		end,
	})
	self.StateChanged = self._machine.StateChanged
	return self
end

function CombatSessionStateMachine:GetState(): InternalCombatSessionState
	return self._machine:GetState()
end

function CombatSessionStateMachine:BeginStart(
	snapshot: CombatSessionLifecycleSnapshot
): Result.Result<InternalCombatSessionState>
	return self:_Transition("Starting", snapshot)
end

function CombatSessionStateMachine:MarkRuntimeReady(
	snapshot: CombatSessionLifecycleSnapshot
): Result.Result<InternalCombatSessionState>
	return self:_Transition("RuntimeReady", snapshot)
end

function CombatSessionStateMachine:Activate(
	snapshot: CombatSessionLifecycleSnapshot
): Result.Result<InternalCombatSessionState>
	return self:_Transition("Active", snapshot)
end

function CombatSessionStateMachine:BeginEnding(
	snapshot: CombatSessionLifecycleSnapshot
): Result.Result<InternalCombatSessionState>
	return self:_Transition("Ending", snapshot)
end

function CombatSessionStateMachine:Fail(
	snapshot: CombatSessionLifecycleSnapshot
): Result.Result<InternalCombatSessionState>
	return self:_Transition("Failed", snapshot)
end

function CombatSessionStateMachine:Clear(
	snapshot: CombatSessionLifecycleSnapshot
): Result.Result<InternalCombatSessionState>
	return self:_Transition("Inactive", snapshot)
end

function CombatSessionStateMachine:Destroy()
	self._machine:Destroy()
end

function CombatSessionStateMachine:_Transition(
	newState: InternalCombatSessionState,
	snapshot: CombatSessionLifecycleSnapshot
): Result.Result<InternalCombatSessionState>
	local validationError = self:_ValidateTargetState(newState, snapshot)
	if validationError ~= nil then
		return validationError
	end

	return self._machine:Transition(newState)
end

function CombatSessionStateMachine:_ValidateTargetState(
	newState: InternalCombatSessionState,
	snapshot: CombatSessionLifecycleSnapshot
): Result.Err?
	local failedInvariants = {}

	if newState == "Starting" then
		_RequireInvariant(failedInvariants, snapshot.HasSessionRecord, "HasSessionRecord")
		_RequireInvariant(failedInvariants, not snapshot.RuntimeStarted, "RuntimeStoppedBeforeStart")
		_RequireInvariant(failedInvariants, not snapshot.RuntimeObjectPresent, "RuntimeObjectAbsentBeforeStart")
		_RequireInvariant(failedInvariants, not snapshot.IsShutdownLocked, "ShutdownUnlockedWhileStarting")
		_RequireInvariant(failedInvariants, not snapshot.HasLifecycleFailure, "NoLifecycleFailureWhileStarting")
	elseif newState == "RuntimeReady" then
		_RequireInvariant(failedInvariants, snapshot.HasSessionRecord, "HasSessionRecord")
		_RequireInvariant(failedInvariants, snapshot.HasRegisteredActorTypes, "HasRegisteredActorTypes")
		_RequireInvariant(failedInvariants, snapshot.RuntimeStarted, "RuntimeStarted")
		_RequireInvariant(failedInvariants, snapshot.RuntimeObjectPresent, "RuntimeObjectPresent")
		_RequireInvariant(failedInvariants, snapshot.QueuedActorRegistrationHealthy, "QueuedActorRegistrationHealthy")
		_RequireInvariant(failedInvariants, not snapshot.IsShutdownLocked, "ShutdownUnlockedWhileRuntimeReady")
		_RequireInvariant(failedInvariants, not snapshot.HasLifecycleFailure, "NoLifecycleFailureWhileRuntimeReady")
	elseif newState == "Active" then
		_RequireInvariant(failedInvariants, snapshot.HasSessionRecord, "HasSessionRecord")
		_RequireInvariant(failedInvariants, snapshot.HasRegisteredActorTypes, "HasRegisteredActorTypes")
		_RequireInvariant(failedInvariants, snapshot.RuntimeStarted, "RuntimeStarted")
		_RequireInvariant(failedInvariants, snapshot.RuntimeObjectPresent, "RuntimeObjectPresent")
		_RequireInvariant(failedInvariants, snapshot.QueuedActorRegistrationHealthy, "QueuedActorRegistrationHealthy")
		_RequireInvariant(failedInvariants, not snapshot.IsShutdownLocked, "ShutdownUnlockedWhileActive")
		_RequireInvariant(failedInvariants, not snapshot.HasLifecycleFailure, "NoLifecycleFailureWhileActive")
	elseif newState == "Ending" then
		_RequireInvariant(failedInvariants, snapshot.HasSessionRecord, "HasSessionRecord")
		_RequireInvariant(failedInvariants, snapshot.IsShutdownLocked, "ShutdownLockedWhileEnding")
	elseif newState == "Failed" then
		_RequireInvariant(failedInvariants, snapshot.HasSessionRecord, "HasSessionRecord")
		_RequireInvariant(failedInvariants, snapshot.IsShutdownLocked, "ShutdownLockedWhileFailed")
		_RequireInvariant(failedInvariants, snapshot.HasLifecycleFailure, "HasLifecycleFailure")
	elseif newState == "Inactive" then
		_RequireInvariant(failedInvariants, snapshot.HasSessionRecord, "HasSessionRecord")
		_RequireInvariant(failedInvariants, snapshot.IsShutdownLocked, "ShutdownLockedWhileClearing")
	else
		table.insert(failedInvariants, "UnknownTargetState")
	end

	if #failedInvariants == 0 then
		return nil
	end

	return Result.Err("CombatSessionInvariantFailed", Errors.COMBAT_SESSION_INVARIANT_FAILED, {
		From = self:GetState(),
		To = newState,
		FailureReason = snapshot.FailureReason,
		FailedInvariants = failedInvariants,
		Snapshot = table.clone(snapshot),
	})
end

return CombatSessionStateMachine
