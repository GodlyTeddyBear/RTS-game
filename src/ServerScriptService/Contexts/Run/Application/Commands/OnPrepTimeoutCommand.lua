--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class OnPrepTimeoutCommand
	Advances the run from `Prep` into the first combat wave.
	@server
]=]
local OnPrepTimeoutCommand = {}
OnPrepTimeoutCommand.__index = OnPrepTimeoutCommand

--[=[
	Creates a new prep-timeout command.
	@within OnPrepTimeoutCommand
	@return OnPrepTimeoutCommand -- The new command instance.
]=]
function OnPrepTimeoutCommand.new()
	return setmetatable({}, OnPrepTimeoutCommand)
end

--[=[
	Wires the state machine and timer dependencies.
	@within OnPrepTimeoutCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function OnPrepTimeoutCommand:Init(registry: any, _name: string)
	self._machine = registry:Get("RunStateMachine")
	self._timer = registry:Get("RunTimerService")
end

--[=[
	Enter `Wave` when the prep countdown expires.
	@within OnPrepTimeoutCommand
	@param onWaveTimeout function -- Callback fired when the wave timer expires.
	@return Result.Result<nil> -- `nil` when the timeout is processed.
]=]
function OnPrepTimeoutCommand:Execute(onWaveTimeout: () -> ()): Result.Result<nil>
	-- Ignore stale callbacks that arrive after the run has already moved on.
	if self._machine:GetState() ~= "Prep" then
		return Ok(nil)
	end

	-- Advance the wave counter before transitioning into active combat.
	self._machine:IncrementWaveNumber()
	Try(self._machine:Transition("Wave"))

	-- Arm the wave countdown after the state machine is already in `Wave`.
	self._timer:StartWaveCountdown(onWaveTimeout)

	return Ok(nil)
end

return OnPrepTimeoutCommand
