--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class StartRunCommand
	Starts a new run after validating that the server is currently idle.
	@server
]=]
local StartRunCommand = {}
StartRunCommand.__index = StartRunCommand

--[=[
	Creates a new start-run command.
	@within StartRunCommand
	@return StartRunCommand -- The new command instance.
]=]
function StartRunCommand.new()
	return setmetatable({}, StartRunCommand)
end

--[=[
	Wires the state machine, timer, and transition policy dependencies.
	@within StartRunCommand
	@param registry any -- The service registry that owns this command.
	@param name string -- The registered module name.
]=]
function StartRunCommand:Init(registry: any, _name: string)
	self._machine = registry:Get("RunStateMachine")
	self._timer = registry:Get("RunTimerService")
	self._transitionPolicy = registry:Get("RunTransitionPolicy")
end

--[=[
	Enter `Prep` and arm the prep countdown.
	@within StartRunCommand
	@param onPrepTimeout function -- Callback fired when prep expires.
	@return Result.Result<boolean> -- `true` when the run is started.
	@error string -- Thrown if the current state is not `Idle`.
]=]
function StartRunCommand:Execute(onPrepTimeout: () -> ()): Result.Result<boolean>
	-- Validate the current phase before changing any run state.
	Try(self._transitionPolicy:CheckCanStartRun(self._machine:GetState()))

	-- Reset run progress, then move into the first active phase.
	self._machine:ResetWaveNumber()
	Try(self._machine:Transition("Prep"))

	-- Arm the prep timeout only after the state machine is already in Prep.
	self._timer:StartPrepCountdown(onPrepTimeout)

	return Ok(true)
end

return StartRunCommand
