--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class NotifyCommanderDeathCommand
	Ends the run when the commander dies or the run is aborted.
	@server
]=]
local NotifyCommanderDeathCommand = {}
NotifyCommanderDeathCommand.__index = NotifyCommanderDeathCommand
setmetatable(NotifyCommanderDeathCommand, BaseCommand)

--[=[
	Creates a new commander-death command.
	@within NotifyCommanderDeathCommand
	@return NotifyCommanderDeathCommand -- The new command instance.
]=]
function NotifyCommanderDeathCommand.new()
	local self = BaseCommand.new("Run", "NotifyCommanderDeath")
	return setmetatable(self, NotifyCommanderDeathCommand)
end

--[=[
	Wires the state machine, timer, and transition policy dependencies.
	@within NotifyCommanderDeathCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function NotifyCommanderDeathCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_machine = "RunStateMachine",
		_timer = "RunTimerService",
		_transitionPolicy = "RunTransitionPolicy"
	})
end

--[=[
	Cancel all timers and enter `RunEnd`.
	@within NotifyCommanderDeathCommand
	@return Result.Result<boolean> -- `true` when the run is terminated.
	@error string -- Thrown if the run is already idle or terminal.
]=]
function NotifyCommanderDeathCommand:Execute(): Result.Result<boolean>
	-- Validate that there is an active run before aborting it.
	Try(self._transitionPolicy:CheckCanNotifyCommanderDeath(self._machine:GetState()))

	-- Stop pending countdowns before entering the terminal state.
	self._timer:Cancel()

	-- Commit the terminal transition after the timer is cleared.
	Try(self._machine:Transition("RunEnd"))

	return Ok(true)
end

return NotifyCommanderDeathCommand


