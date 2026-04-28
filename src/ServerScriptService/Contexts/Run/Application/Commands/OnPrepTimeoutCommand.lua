--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class OnPrepTimeoutCommand
	Advances the run from `Prep` into the first combat wave.
	@server
]=]
local OnPrepTimeoutCommand = {}
OnPrepTimeoutCommand.__index = OnPrepTimeoutCommand
setmetatable(OnPrepTimeoutCommand, BaseCommand)

--[=[
	Creates a new prep-timeout command.
	@within OnPrepTimeoutCommand
	@return OnPrepTimeoutCommand -- The new command instance.
]=]
function OnPrepTimeoutCommand.new()
	local self = BaseCommand.new("Run", "OnPrepTimeout")
	return setmetatable(self, OnPrepTimeoutCommand)
end

--[=[
	Wires the state machine and timer dependencies.
	@within OnPrepTimeoutCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function OnPrepTimeoutCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_machine = "RunStateMachine",
		_timer = "RunTimerService"
	})
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

	-- Advance the wave counter and arm the wave countdown before state sync fires.
	self._machine:IncrementWaveNumber()
	self._timer:StartWaveCountdown(onWaveTimeout)
	Try(self._machine:Transition("Wave"))

	return Ok(nil)
end

return OnPrepTimeoutCommand


