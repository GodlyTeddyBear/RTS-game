--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class NotifyWaveClearedCommand
	Ends the current wave early and moves the run into resolution.
	@server
]=]
local NotifyWaveClearedCommand = {}
NotifyWaveClearedCommand.__index = NotifyWaveClearedCommand
setmetatable(NotifyWaveClearedCommand, BaseCommand)

--[=[
	Creates a new wave-cleared command.
	@within NotifyWaveClearedCommand
	@return NotifyWaveClearedCommand -- The new command instance.
]=]
function NotifyWaveClearedCommand.new()
	local self = BaseCommand.new("Run", "NotifyWaveCleared")
	return setmetatable(self, NotifyWaveClearedCommand)
end

--[=[
	Wires the state machine, timer, and transition policy dependencies.
	@within NotifyWaveClearedCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function NotifyWaveClearedCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_machine = "RunStateMachine",
		_timer = "RunTimerService",
		_transitionPolicy = "RunTransitionPolicy"
	})
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

	-- Arm resolution before the transition so sync carries the breather deadline.
	self._timer:StartResolutionCountdown(onResolutionTimeout)
	Try(self._machine:Transition("Resolution"))

	return Ok(true)
end

return NotifyWaveClearedCommand


