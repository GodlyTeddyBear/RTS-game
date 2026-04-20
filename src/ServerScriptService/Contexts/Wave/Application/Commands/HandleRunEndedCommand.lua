--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

--[=[
	@class HandleRunEndedCommand
	Resets the wave session when the run ends.
	@server
]=]
local HandleRunEndedCommand = {}
HandleRunEndedCommand.__index = HandleRunEndedCommand

--[=[
	Creates a new run-ended handler command.
	@within HandleRunEndedCommand
	@return HandleRunEndedCommand -- The new command instance.
]=]
function HandleRunEndedCommand.new()
	return setmetatable({}, HandleRunEndedCommand)
end

--[=[
	Wires the scheduler and runtime state dependencies.
	@within HandleRunEndedCommand
	@param registry any -- The owning registry.
	@param name string -- The registered module name.
]=]
function HandleRunEndedCommand:Init(registry: any, _name: string)
	self._scheduler = registry:Get("WaveSpawnScheduler")
	self._state = registry:Get("WaveRuntimeStateService")
	self._lifecycle = registry:Get("WaveLifecycleService")
end

--[=[
	Cancels pending wave spawns and restores the inactive runtime snapshot.
	@within HandleRunEndedCommand
	@return Result.Result<nil> -- `Ok(nil)` when the reset completes.
]=]
function HandleRunEndedCommand:Execute(): Result.Result<nil>
	-- Clear stale tasks first so no delayed callback can mutate the reset state.
	self._scheduler:CancelAll()
	self._state:SetState(self._lifecycle:ResetState())
	return Ok(nil)
end

return HandleRunEndedCommand
