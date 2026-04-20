--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local RunSpecs = require(script.Parent.Parent.Specs.RunSpecs)

local Ok = Result.Ok
local Try = Result.Try

type RunState = RunTypes.RunState

--[=[
	@class RunTransitionPolicy
	Evaluates the domain rules that gate run state transitions.
	@server
]=]
local RunTransitionPolicy = {}
RunTransitionPolicy.__index = RunTransitionPolicy

--[=[
	Creates a new run-transition policy.
	@within RunTransitionPolicy
	@return RunTransitionPolicy -- The new policy instance.
]=]
function RunTransitionPolicy.new()
	return setmetatable({}, RunTransitionPolicy)
end

--[=[
	Initializes the policy for registry ownership.
	@within RunTransitionPolicy
	@param registry any -- The service registry that owns this policy.
	@param name string -- The registered module name.
]=]
function RunTransitionPolicy:Init(_registry: any, _name: string)
end

-- Converts the raw run state into the spec candidate shape so each rule sees a consistent input.
local function createStateCandidate(state: RunState): RunSpecs.TStateCandidate
	return {
		State = state,
	}
end

--[=[
	Validate the run state for `StartRun`.
	@within RunTransitionPolicy
	@param state RunState -- The current authoritative run state.
	@return Result.Result<nil> -- `Ok` when the run may start.
]=]
function RunTransitionPolicy:CheckCanStartRun(state: RunState): Result.Result<nil>
	Try(RunSpecs.CanStartRun:IsSatisfiedBy(createStateCandidate(state)))
	return Ok(nil)
end

--[=[
	Validate the run state for `NotifyWaveCleared`.
	@within RunTransitionPolicy
	@param state RunState -- The current authoritative run state.
	@return Result.Result<nil> -- `Ok` when the wave may be cleared.
]=]
function RunTransitionPolicy:CheckCanNotifyWaveCleared(state: RunState): Result.Result<nil>
	Try(RunSpecs.CanNotifyWaveCleared:IsSatisfiedBy(createStateCandidate(state)))
	return Ok(nil)
end

--[=[
	Validate the run state for `NotifyClimaxComplete`.
	@within RunTransitionPolicy
	@param state RunState -- The current authoritative run state.
	@return Result.Result<nil> -- `Ok` when the climax may complete.
]=]
function RunTransitionPolicy:CheckCanNotifyClimaxComplete(state: RunState): Result.Result<nil>
	Try(RunSpecs.CanNotifyClimaxComplete:IsSatisfiedBy(createStateCandidate(state)))
	return Ok(nil)
end

--[=[
	Validate the run state for `NotifyCommanderDeath`.
	@within RunTransitionPolicy
	@param state RunState -- The current authoritative run state.
	@return Result.Result<nil> -- `Ok` when the run may end.
]=]
function RunTransitionPolicy:CheckCanNotifyCommanderDeath(state: RunState): Result.Result<nil>
	Try(RunSpecs.CanNotifyCommanderDeath:IsSatisfiedBy(createStateCandidate(state)))
	return Ok(nil)
end

return RunTransitionPolicy
