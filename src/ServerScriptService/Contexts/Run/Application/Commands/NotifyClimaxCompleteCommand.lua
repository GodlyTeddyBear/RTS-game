--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class NotifyClimaxCompleteCommand
	Ends the climax and transitions the run into endless waves.
	@server
]=]
local NotifyClimaxCompleteCommand = {}
NotifyClimaxCompleteCommand.__index = NotifyClimaxCompleteCommand
setmetatable(NotifyClimaxCompleteCommand, BaseCommand)

--[=[
	Creates a new climax-complete command.
	@within NotifyClimaxCompleteCommand
	@return NotifyClimaxCompleteCommand -- The new command instance.
]=]
function NotifyClimaxCompleteCommand.new()
	local self = BaseCommand.new("Run", "NotifyClimaxComplete")
	return setmetatable(self, NotifyClimaxCompleteCommand)
end

--[=[
	Wires the state machine, timer, and transition policy dependencies.
	@within NotifyClimaxCompleteCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function NotifyClimaxCompleteCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_machine = "RunStateMachine",
		_timer = "RunTimerService",
		_transitionPolicy = "RunTransitionPolicy"
	})
end

--[=[
	Enter `Endless` and start the endless wave countdown.
	@within NotifyClimaxCompleteCommand
	@param onWaveTimeout function -- Callback fired when the endless wave timer expires.
	@return Result.Result<boolean> -- `true` when the transition is accepted.
	@error string -- Thrown if the current state is not `Climax`.
]=]
function NotifyClimaxCompleteCommand:Execute(onWaveTimeout: () -> ()): Result.Result<boolean>
	-- Validate that the climax is the active phase before advancing.
	Try(self._transitionPolicy:CheckCanNotifyClimaxComplete(self._machine:GetState()))

	-- Increment the wave counter before the endless loop starts.
	self._machine:IncrementWaveNumber()

	-- Arm the shared wave timer before exposing the endless phase snapshot.
	self._timer:StartWaveCountdown(onWaveTimeout)
	Try(self._machine:Transition("Endless"))

	return Ok(true)
end

return NotifyClimaxCompleteCommand


