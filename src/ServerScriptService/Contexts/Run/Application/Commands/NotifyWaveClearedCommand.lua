--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class NotifyWaveClearedCommand
	Ends the current wave early and moves the run into resolution.
	@server
]=]
local NotifyWaveClearedCommand = {}
NotifyWaveClearedCommand.__index = NotifyWaveClearedCommand

--[=[
	Creates a new wave-cleared command.
	@within NotifyWaveClearedCommand
	@return NotifyWaveClearedCommand -- The new command instance.
]=]
function NotifyWaveClearedCommand.new()
	return setmetatable({}, NotifyWaveClearedCommand)
end

--[=[
	Wires the state machine, timer, and transition policy dependencies.
	@within NotifyWaveClearedCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function NotifyWaveClearedCommand:Init(registry: any, _name: string)
	self._machine = registry:Get("RunStateMachine")
	self._timer = registry:Get("RunTimerService")
	self._transitionPolicy = registry:Get("RunTransitionPolicy")
end

--[=[
	Cancel the wave timer and enter `Resolution`.
	@within NotifyWaveClearedCommand
	@param onResolutionTimeout function -- Callback fired when resolution expires.
	@return Result.Result<boolean> -- `true` when the transition is accepted.
	@error string -- Thrown if the current state is not `Wave`.
]=]
function NotifyWaveClearedCommand:Execute(onResolutionTimeout: () -> ()): Result.Result<boolean>
	-- Validate the current combat phase before touching timers.
	Try(self._transitionPolicy:CheckCanNotifyWaveCleared(self._machine:GetState()))

	-- Stop the active wave countdown before scheduling the resolution timer.
	self._timer:Cancel()

	-- Move into resolution and arm the next countdown in one sequence.
	Try(self._machine:Transition("Resolution"))
	self._timer:StartResolutionCountdown(onResolutionTimeout)

	return Ok(true)
end

return NotifyWaveClearedCommand
