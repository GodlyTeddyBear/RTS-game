--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local RunTypes = require(ReplicatedStorage.Contexts.Run.Types.RunTypes)
local RunConfig = require(ReplicatedStorage.Contexts.Run.Config.RunConfig)
local RunTravelConfig = require(ReplicatedStorage.Contexts.Run.Config.RunTravelConfig)
local CommandRegistry = require(ReplicatedStorage.Contexts.Log.CommandRegistry)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local BlinkServer = require(ReplicatedStorage.Network.Generated.RunSyncServer)

local RunStateMachine = require(script.Parent.Infrastructure.Services.RunStateMachine)
local RunTimerService = require(script.Parent.Infrastructure.Services.RunTimerService)
local RunSyncService = require(script.Parent.Infrastructure.Persistence.RunSyncService)
local RunTransitionPolicy = require(script.Parent.RunDomain.Policies.RunTransitionPolicy)
local StartRunCommand = require(script.Parent.Application.Commands.StartRunCommand)
local NotifyWaveClearedCommand = require(script.Parent.Application.Commands.NotifyWaveClearedCommand)
local NotifyClimaxCompleteCommand = require(script.Parent.Application.Commands.NotifyClimaxCompleteCommand)
local NotifyCommanderDeathCommand = require(script.Parent.Application.Commands.NotifyCommanderDeathCommand)
local OnPrepTimeoutCommand = require(script.Parent.Application.Commands.OnPrepTimeoutCommand)
local OnWaveTimeoutCommand = require(script.Parent.Application.Commands.OnWaveTimeoutCommand)
local OnResolutionTimeoutCommand = require(script.Parent.Application.Commands.OnResolutionTimeoutCommand)
local GetRunStateQuery = require(script.Parent.Application.Queries.GetRunStateQuery)
local GetWaveNumberQuery = require(script.Parent.Application.Queries.GetWaveNumberQuery)
local Errors = require(script.Parent.Errors)

local Catch = Result.Catch
local Err = Result.Err
local Ok = Result.Ok
local Try = Result.Try

type RunState = RunTypes.RunState
type RunSnapshot = RunTypes.RunSnapshot

--[=[
	@class RunContext
	Owns the authoritative run state machine and bridges it to other contexts.
	@server
]=]
local RunContext = Knit.CreateService({
	Name = "RunContext",
	Client = {},
})

--[=[
	@prop StateChanged RBXScriptSignal
	@within RunContext
	Fires when the authoritative run state changes.
]=]
RunContext.StateChanged = nil

--[=[
	Initializes the run state machine, timers, and shared sync atom.
	@within RunContext
]=]
function RunContext:KnitInit()
	-- Register infrastructure and application modules before context methods are callable.
	local registry = Registry.new("Server")
	registry:Register("BlinkServer", BlinkServer)
	registry:Register("RunStateMachine", RunStateMachine.new(), "Infrastructure")
	registry:Register("RunTimerService", RunTimerService.new(RunConfig), "Infrastructure")
	registry:Register("RunSyncService", RunSyncService.new(), "Infrastructure")
	registry:Register("RunTransitionPolicy", RunTransitionPolicy.new(), "Domain")
	registry:Register("StartRunCommand", StartRunCommand.new(), "Application")
	registry:Register("NotifyWaveClearedCommand", NotifyWaveClearedCommand.new(), "Application")
	registry:Register("NotifyClimaxCompleteCommand", NotifyClimaxCompleteCommand.new(), "Application")
	registry:Register("NotifyCommanderDeathCommand", NotifyCommanderDeathCommand.new(), "Application")
	registry:Register("OnPrepTimeoutCommand", OnPrepTimeoutCommand.new(), "Application")
	registry:Register("OnWaveTimeoutCommand", OnWaveTimeoutCommand.new(), "Application")
	registry:Register("OnResolutionTimeoutCommand", OnResolutionTimeoutCommand.new(), "Application")
	registry:Register("GetRunStateQuery", GetRunStateQuery.new(), "Application")
	registry:Register("GetWaveNumberQuery", GetWaveNumberQuery.new(), "Application")
	registry:InitAll()

	-- Cache the resolved modules so the public Run API stays thin.
	self._machine = registry:Get("RunStateMachine")
	self._sync = registry:Get("RunSyncService")
	self._transitionPolicy = registry:Get("RunTransitionPolicy")
	self._startRunCommand = registry:Get("StartRunCommand")
	self._notifyWaveClearedCommand = registry:Get("NotifyWaveClearedCommand")
	self._notifyClimaxCompleteCommand = registry:Get("NotifyClimaxCompleteCommand")
	self._notifyCommanderDeathCommand = registry:Get("NotifyCommanderDeathCommand")
	self._onPrepTimeoutCommand = registry:Get("OnPrepTimeoutCommand")
	self._onWaveTimeoutCommand = registry:Get("OnWaveTimeoutCommand")
	self._onResolutionTimeoutCommand = registry:Get("OnResolutionTimeoutCommand")
	self._getRunStateQuery = registry:Get("GetRunStateQuery")
	self._getWaveNumberQuery = registry:Get("GetWaveNumberQuery")

	self:_RegisterDeveloperLogCommands()

	-- Build timeout delegates once so application commands own all transition rules.
	-- Prep timeout hands control to the wave entry command chain.
	self._onPrepTimeout = function()
		Catch(function()
			Try(self._onPrepTimeoutCommand:Execute(self._onWaveTimeout))
			return Ok(nil)
		end, "Run:_OnPrepTimeout")
	end

	-- Wave timeout advances the run into the resolution phase.
	self._onWaveTimeout = function()
		Catch(function()
			Try(self._onWaveTimeoutCommand:Execute(self._onResolutionTimeout))
			return Ok(nil)
		end, "Run:_OnWaveTimeout")
	end

	-- Resolution timeout loops back into prep unless a later command interrupts the run.
	self._onResolutionTimeout = function()
		Catch(function()
			Try(self._onResolutionTimeoutCommand:Execute(self._onPrepTimeout))
			return Ok(nil)
		end, "Run:_OnResolutionTimeout")
	end

	self.StateChanged = self._machine.StateChanged
	self._stateChangedConnection = self._machine.StateChanged:Connect(function(newState: RunState, previousState: RunState)
		self:_OnStateChanged(newState, previousState)
	end)

	self._sync:SetState(self:_BuildRunSnapshot())
end

local function _formatCommandFailure(commandName: string, result: Result.Result<any>): (boolean, string)
	return false, string.format("%s failed: %s", commandName, result.message)
end

local function _ResolveSpawnCFrame(markerName: string, fallbackCFrame: CFrame): CFrame
	local marker = Workspace:FindFirstChild(markerName, true)
	if marker == nil then
		return fallbackCFrame
	end

	if marker:IsA("BasePart") then
		return marker.CFrame
	end

	if marker:IsA("Model") then
		return marker:GetPivot()
	end

	return fallbackCFrame
end

function RunContext:_RegisterDeveloperLogCommands()
	CommandRegistry.Register({
		name = "Run.Start",
		context = "Run",
		description = "Start a run from Idle or RunEnd.",
		handler = function(_params: { [string]: string }): (boolean, string)
			local result = self:StartRun()
			if not result.success then
				return _formatCommandFailure("Run.Start", result)
			end

			Result.MentionEvent("RunContext:DevCommand", "Run.Start", {
				State = self._machine:GetState(),
				WaveNumber = self._machine:GetWaveNumber(),
			})
			return true, string.format("Run started. state=%s wave=%d", self._machine:GetState(), self._machine:GetWaveNumber())
		end,
	})

	CommandRegistry.Register({
		name = "Run.Restart",
		context = "Run",
		description = "Return to lobby by transitioning the run to Idle.",
		handler = function(_params: { [string]: string }): (boolean, string)
			local result = self:RestartRun()
			if not result.success then
				return _formatCommandFailure("Run.Restart", result)
			end

			Result.MentionEvent("RunContext:DevCommand", "Run.Restart", {
				State = self._machine:GetState(),
				WaveNumber = self._machine:GetWaveNumber(),
			})
			return true, string.format("Returned to lobby. state=%s wave=%d", self._machine:GetState(), self._machine:GetWaveNumber())
		end,
	})

	CommandRegistry.Register({
		name = "Run.Reset",
		context = "Run",
		description = "Force reset and immediately start a fresh run.",
		handler = function(_params: { [string]: string }): (boolean, string)
			local result = self:ResetRun()
			if not result.success then
				return _formatCommandFailure("Run.Reset", result)
			end

			Result.MentionEvent("RunContext:DevCommand", "Run.Reset", {
				State = self._machine:GetState(),
				WaveNumber = self._machine:GetWaveNumber(),
			})
			return true, string.format("Run reset. state=%s wave=%d", self._machine:GetState(), self._machine:GetWaveNumber())
		end,
	})

	CommandRegistry.Register({
		name = "Run.SkipPhase",
		context = "Run",
		description = "Advance to the next run phase immediately.",
		handler = function(_params: { [string]: string }): (boolean, string)
			local result = self:SkipCurrentPhase()
			if not result.success then
				return _formatCommandFailure("Run.SkipPhase", result)
			end

			Result.MentionEvent("RunContext:DevCommand", "Run.SkipPhase", {
				State = self._machine:GetState(),
				WaveNumber = self._machine:GetWaveNumber(),
			})
			return true, string.format("Phase skipped. state=%s wave=%d", self._machine:GetState(), self._machine:GetWaveNumber())
		end,
	})
end

--[=[
	Starts hydration for players already present and players who join later.
	@within RunContext
]=]
function RunContext:KnitStart()
	-- Hydrate late joiners so they receive the current global run snapshot.
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player: Player)
		self._sync:HydratePlayer(player)
	end)

	-- Hydrate players already in the server before this context finished starting.
	for _, player in Players:GetPlayers() do
		self._sync:HydratePlayer(player)
	end

	-- Listen for commander death through the shared event bus so run termination stays decoupled.
	self._commanderDiedConnection = GameEvents.Bus:On(GameEvents.Events.Commander.CommanderDied, function(_player: Instance)
		-- Convert the event into the existing run-termination command flow.
		Catch(function()
			Try(self:NotifyCommanderDeath())
			return Ok(nil)
		end, "Run:OnCommanderDied")
	end)
end

--[=[
	Returns the current authoritative run state.
	@within RunContext
	@return Result.Result<RunState> -- The current state wrapped in `Result`.
]=]
function RunContext:GetState(): Result.Result<RunState>
	return Catch(function()
		return Ok(self._getRunStateQuery:Execute())
	end, "Run:GetState")
end

--[=[
	Returns the current authoritative wave number.
	@within RunContext
	@return Result.Result<number> -- The current wave number wrapped in `Result`.
]=]
function RunContext:GetWaveNumber(): Result.Result<number>
	return Catch(function()
		return Ok(self._getWaveNumberQuery:Execute())
	end, "Run:GetWaveNumber")
end

--[=[
	Starts the run from `Idle` and arms the prep countdown.
	@within RunContext
	@return Result.Result<boolean> -- Whether the run successfully started.
]=]
function RunContext:StartRun(): Result.Result<boolean>
	return Catch(function()
		Try(self._transitionPolicy:CheckCanStartRun(self._machine:GetState()))
		self:_TeleportPlayersToCFrame(self:_GetPhase2EntryCFrame())
		return self._startRunCommand:Execute(self._onPrepTimeout)
	end, "Run:StartRun")
end

--[=[
	Restarts the session back to lobby by entering `Idle`.
	@within RunContext
	@return Result.Result<boolean> -- Whether the run successfully returned to lobby.
]=]
function RunContext:RestartRun(): Result.Result<boolean>
	return Catch(function()
		local state = self._machine:GetState()
		if state ~= "Idle" and state ~= "RunEnd" then
			Try(self._notifyCommanderDeathCommand:Execute())
			state = self._machine:GetState()
		end

		if state == "RunEnd" then
			Try(self._machine:Transition("Idle"))
		end

		return Ok(true)
	end, "Run:RestartRun")
end

--[=[
	Resets the current run and immediately starts a fresh run in `Prep`.
	@within RunContext
	@return Result.Result<boolean> -- Whether the run successfully reset and started.
]=]
function RunContext:ResetRun(): Result.Result<boolean>
	return Catch(function()
		local state = self._machine:GetState()
		if state ~= "Idle" and state ~= "RunEnd" then
			Try(self._notifyCommanderDeathCommand:Execute())
			state = self._machine:GetState()
		end

		if state == "RunEnd" then
			Try(self._machine:Transition("Idle"))
		end

		return self:StartRun()
	end, "Run:ResetRun")
end

--[=[
	Advances from `Wave` to `Resolution` when the wave ends early.
	@within RunContext
	@return Result.Result<boolean> -- Whether the wave was successfully cleared.
]=]
function RunContext:NotifyWaveCleared(): Result.Result<boolean>
	return Catch(function()
		return self._notifyWaveClearedCommand:Execute(self._onResolutionTimeout)
	end, "Run:NotifyWaveCleared")
end

--[=[
	Completes the climax and enters the endless loop.
	@within RunContext
	@return Result.Result<boolean> -- Whether the climax completion was accepted.
]=]
function RunContext:NotifyClimaxComplete(): Result.Result<boolean>
	return Catch(function()
		return self._notifyClimaxCompleteCommand:Execute(self._onWaveTimeout)
	end, "Run:NotifyClimaxComplete")
end

--[=[
	Ends the run when the commander dies or the server otherwise aborts the run.
	@within RunContext
	@return Result.Result<boolean> -- Whether the run was transitioned into `RunEnd`.
]=]
function RunContext:NotifyCommanderDeath(): Result.Result<boolean>
	return Catch(function()
		return self._notifyCommanderDeathCommand:Execute()
	end, "Run:NotifyCommanderDeath")
end

--[=[
	Skips the current active phase and executes its transition immediately.
	@within RunContext
	@return Result.Result<boolean> -- Whether a phase skip was performed.
]=]
function RunContext:SkipCurrentPhase(): Result.Result<boolean>
	return Catch(function()
		local state = self._machine:GetState()
		if state == "Prep" then
			Try(self._onPrepTimeoutCommand:Execute(self._onWaveTimeout))
			return Ok(true)
		end

		if state == "Wave" or state == "Endless" then
			Try(self._onWaveTimeoutCommand:Execute(self._onResolutionTimeout))
			return Ok(true)
		end

		if state == "Resolution" then
			Try(self._onResolutionTimeoutCommand:Execute(self._onPrepTimeout))
			return Ok(true)
		end

		if state == "Climax" then
			return self._notifyClimaxCompleteCommand:Execute(self._onWaveTimeout)
		end

		return Err("InvalidStateForNotify", Errors.INVALID_STATE_FOR_NOTIFY, {
			State = state,
		})
	end, "Run:SkipCurrentPhase")
end

--[=[
	Requests a run start from the client lobby flow.
	@within RunContext
	@param _player Player -- The requesting player.
	@return boolean -- `true` when the run successfully started.
]=]
function RunContext.Client:RequestStartRun(player: Player): boolean
	if player.Character == nil then
		return false
	end

	local result = self.Server:StartRun()
	return result.success
end

--[=[
	Requests a run restart from the client.
	@within RunContext
	@param _player Player -- The requesting player.
	@return boolean -- `true` when restart succeeded.
]=]
function RunContext.Client:RequestRestartRun(_player: Player): boolean
	local state = self.Server._machine:GetState()
	if state ~= "Idle" and state ~= "RunEnd" then
		return false
	end

	local result = self.Server:ResetRun()
	if result.success then
		return true
	end

	return false
end

function RunContext:_GetPhase2EntryCFrame(): CFrame
	return _ResolveSpawnCFrame(RunTravelConfig.PHASE2_ENTRY_MARKER_NAME, RunTravelConfig.PHASE2_ENTRY_CFRAME)
end

function RunContext:_GetLobbyReturnCFrame(): CFrame
	return _ResolveSpawnCFrame(RunTravelConfig.LOBBY_RETURN_MARKER_NAME, RunTravelConfig.LOBBY_RETURN_CFRAME)
end

function RunContext:_TeleportPlayersToCFrame(targetCFrame: CFrame)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:IsA("BasePart") then
				rootPart.AssemblyLinearVelocity = Vector3.zero
				rootPart.AssemblyAngularVelocity = Vector3.zero
				rootPart.CFrame = targetCFrame
			end
		end
	end
end

function RunContext:_BuildRunSnapshot(): RunSnapshot
	local phaseClock = self._timer:GetPhaseClock()
	return {
		state = self._machine:GetState(),
		waveNumber = self._machine:GetWaveNumber(),
		phaseStartedAt = phaseClock.phaseStartedAt,
		phaseEndsAt = phaseClock.phaseEndsAt,
		phaseDuration = phaseClock.phaseDuration,
	}
end

-- Pushes the new run snapshot to sync, then emits milestone logs for lifecycle transitions.
function RunContext:_OnStateChanged(newState: RunState, previousState: RunState)
	-- Replicate the latest authoritative snapshot before observers react to the transition.
	self._sync:SetState(self:_BuildRunSnapshot())

	Result.MentionEvent("RunContext:RunStateMachine", "State -> " .. newState, {
		PreviousState = previousState,
		WaveNumber = self._machine:GetWaveNumber(),
	})

	-- The idle-to-prep transition is the canonical run-start lifecycle hook.
	if previousState == "Idle" and newState == "Prep" then
		Result.MentionEvent("RunContext:RunStart", "Prep entered from idle", {
			WaveNumber = self._machine:GetWaveNumber(),
		})
	end

	-- Terminal cleanup hooks will be attached here as downstream systems are implemented.
	if newState == "RunEnd" then
		self:_TeleportPlayersToCFrame(self:_GetLobbyReturnCFrame())
		Result.MentionEvent("RunContext:RunEnd", "Run ended; lifecycle cleanup hook", {
			WaveNumber = self._machine:GetWaveNumber(),
		})
	end

	-- Emit run lifecycle events after the sync snapshot is updated so downstream listeners read the latest state.
	if newState == "Resolution" and (previousState == "Wave" or previousState == "Endless") then
		GameEvents.Bus:Emit(GameEvents.Events.Run.WaveEnded, self._machine:GetWaveNumber())
	elseif newState == "Wave" then
		GameEvents.Bus:Emit(GameEvents.Events.Run.WaveStarted, self._machine:GetWaveNumber(), false)
	elseif newState == "Endless" then
		GameEvents.Bus:Emit(GameEvents.Events.Run.WaveStarted, self._machine:GetWaveNumber(), true)
	elseif newState == "RunEnd" then
		GameEvents.Bus:Emit(GameEvents.Events.Run.RunEnded)
	end
end

--[=[
	Cancels run lifecycle subscriptions and state listeners.
	@within RunContext
]=]
function RunContext:Destroy()
	if self._playerAddedConnection then
		self._playerAddedConnection:Disconnect()
	end

	if self._commanderDiedConnection then
		self._commanderDiedConnection:Disconnect()
	end

	if self._stateChangedConnection then
		self._stateChangedConnection:Disconnect()
	end
end

WrapContext(RunContext, "Run")

return RunContext
