--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local RunConfig = require(ReplicatedStorage.Contexts.Run.Config.RunConfig)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class OnResolutionTimeoutCommand
	Loops the run back to prep or routes it into climax.
	@server
]=]
local OnResolutionTimeoutCommand = {}
OnResolutionTimeoutCommand.__index = OnResolutionTimeoutCommand

--[=[
	Creates a new resolution-timeout command.
	@within OnResolutionTimeoutCommand
	@return OnResolutionTimeoutCommand -- The new command instance.
]=]
function OnResolutionTimeoutCommand.new()
	return setmetatable({}, OnResolutionTimeoutCommand)
end

--[=[
	Wires the state machine and timer dependencies.
	@within OnResolutionTimeoutCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function OnResolutionTimeoutCommand:Init(registry: any, _name: string)
	self._machine = registry:Get("RunStateMachine")
	self._timer = registry:Get("RunTimerService")
end

--[=[
	Either re-enter `Prep` or transition into `Climax` when resolution expires.
	@within OnResolutionTimeoutCommand
	@param onPrepTimeout function -- Callback fired when the next prep countdown expires.
	@return Result.Result<nil> -- `nil` when the timeout is processed.
]=]
function OnResolutionTimeoutCommand:Execute(onPrepTimeout: () -> ()): Result.Result<nil>
	-- Ignore stale callbacks if the server already left resolution.
	if self._machine:GetState() ~= "Resolution" then
		return Ok(nil)
	end

	-- Route to climax once the configured wave threshold has been reached.
	if self._machine:GetWaveNumber() >= RunConfig.CLIMAX_WAVE then
		self._timer:ClearPhaseClock()
		Try(self._machine:Transition("Climax"))
		return Ok(nil)
	end

	-- Otherwise loop back into prep and arm the next prep countdown before sync.
	self._timer:StartPrepCountdown(onPrepTimeout)
	Try(self._machine:Transition("Prep"))

	return Ok(nil)
end

return OnResolutionTimeoutCommand
