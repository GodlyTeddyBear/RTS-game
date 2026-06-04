--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class NotifyRunFailedCommand
	Ends the run when the base is destroyed or the run is otherwise aborted.
	@server
]=]
local NotifyRunFailedCommand = {}
NotifyRunFailedCommand.__index = NotifyRunFailedCommand
setmetatable(NotifyRunFailedCommand, BaseCommand)

function NotifyRunFailedCommand.new()
	local self = BaseCommand.new("Run", "NotifyRunFailed")
	return setmetatable(self, NotifyRunFailedCommand)
end

function NotifyRunFailedCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_machine = "RunStateMachine",
		_timer = "RunTimerService",
		_transitionPolicy = "RunTransitionPolicy",
	})
end

function NotifyRunFailedCommand:Execute(): Result.Result<boolean>
	Try(self._transitionPolicy:CheckCanNotifyRunFailed(self._machine:GetState()))

	self._timer:Cancel()
	Try(self._machine:Transition("RunEnd"))

	return Ok(true)
end

return NotifyRunFailedCommand
