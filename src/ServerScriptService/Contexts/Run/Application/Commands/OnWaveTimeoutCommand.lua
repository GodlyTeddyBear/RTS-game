--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class OnWaveTimeoutCommand
	Advances the run from `Wave` or `Endless` into `Resolution`.
	@server
]=]
local OnWaveTimeoutCommand = {}
OnWaveTimeoutCommand.__index = OnWaveTimeoutCommand

--[=[
	Creates a new wave-timeout command.
	@within OnWaveTimeoutCommand
	@return OnWaveTimeoutCommand -- The new command instance.
]=]
function OnWaveTimeoutCommand.new()
	return setmetatable({}, OnWaveTimeoutCommand)
end

--[=[
	Wires the state machine and timer dependencies.
	@within OnWaveTimeoutCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function OnWaveTimeoutCommand:Init(registry: any, _name: string)
	self._machine = registry:Get("RunStateMachine")
	self._timer = registry:Get("RunTimerService")
end

--[=[
	Enter `Resolution` when the wave timer expires.
	@within OnWaveTimeoutCommand
	@param onResolutionTimeout function -- Callback fired when resolution expires.
	@return Result.Result<nil> -- `nil` when the timeout is processed.
]=]
function OnWaveTimeoutCommand:Execute(onResolutionTimeout: () -> ()): Result.Result<nil>
	-- Ignore stale callbacks when the run has already moved out of combat.
	local state = self._machine:GetState()
	if state ~= "Wave" and state ~= "Endless" then
		return Ok(nil)
	end

	-- Arm the cleanup timer before state sync exposes the breather deadline.
	self._timer:StartResolutionCountdown(onResolutionTimeout)
	Try(self._machine:Transition("Resolution"))

	return Ok(nil)
end

return OnWaveTimeoutCommand
