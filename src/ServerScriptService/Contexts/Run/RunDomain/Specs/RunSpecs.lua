--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Spec = require(ReplicatedStorage.Utilities.Specification)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local Errors = require(script.Parent.Parent.Parent.Errors)

type RunState = RunTypes.RunState

--[=[
	@class RunSpecs
	Defines the reusable run eligibility rules used by the transition policy.
	@server
]=]
local RunSpecs = {}

--[=[
	@interface TStateCandidate
	@within RunSpecs
	.State RunState -- The current run state to evaluate.
]=]
export type TStateCandidate = {
	State: RunState,
}

local IsIdleOrRunEnd = Spec.new("IllegalTransition", Errors.ILLEGAL_TRANSITION, function(ctx: TStateCandidate)
	return ctx.State == "Idle" or ctx.State == "RunEnd"
end)

local IsWave = Spec.new("InvalidStateForNotify", Errors.INVALID_STATE_FOR_NOTIFY, function(ctx: TStateCandidate)
	return ctx.State == "Wave"
end)

local IsClimax = Spec.new("InvalidStateForNotify", Errors.INVALID_STATE_FOR_NOTIFY, function(ctx: TStateCandidate)
	return ctx.State == "Climax"
end)

local IsActiveRun = Spec.new("InvalidStateForNotify", Errors.INVALID_STATE_FOR_NOTIFY, function(ctx: TStateCandidate)
	return ctx.State ~= "Idle" and ctx.State ~= "RunEnd"
end)

--[=[
	@prop CanStartRun any
	@within RunSpecs
	Spec that accepts `Idle` and `RunEnd` states.
]=]
RunSpecs.CanStartRun = IsIdleOrRunEnd

--[=[
	@prop CanNotifyWaveCleared any
	@within RunSpecs
	Spec that accepts only the `Wave` state.
]=]
RunSpecs.CanNotifyWaveCleared = IsWave

--[=[
	@prop CanNotifyClimaxComplete any
	@within RunSpecs
	Spec that accepts only the `Climax` state.
]=]
RunSpecs.CanNotifyClimaxComplete = IsClimax

--[=[
	@prop CanNotifyCommanderDeath any
	@within RunSpecs
	Spec that accepts any active run state.
]=]
RunSpecs.CanNotifyCommanderDeath = IsActiveRun

return table.freeze(RunSpecs)
