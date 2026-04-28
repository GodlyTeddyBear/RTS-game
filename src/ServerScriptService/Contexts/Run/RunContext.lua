--!strict

--[[
    Module: RunContext
    Purpose: Owns the authoritative run lifecycle service and bridges run state to other contexts.
    Used In System: Loaded by Knit on the server to manage run start, restart, reset, phase advance, and sync hydration.
    Boundaries: Does not own transition rules, timeout behavior, sync persistence internals, or client UI logic.
    High-Level Flow: Register runtime modules -> hydrate sync -> react to state changes -> expose client requests.
]]

-- [Dependencies]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local ModelPlus = require(ReplicatedStorage.Utilities.ModelPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
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
local Ensure = Result.Ensure

-- [Types]

type RunState = RunTypes.RunState
type RunSnapshot = RunTypes.RunSnapshot

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "BlinkServer",
		Instance = BlinkServer,
	},
	{
		Name = "RunStateMachine",
		Module = RunStateMachine,
		CacheAs = "_machine",
	},
	{
		Name = "RunTimerService",
		Module = RunTimerService,
		Args = { RunConfig },
		CacheAs = "_timer",
	},
	{
		Name = "RunSyncService",
		Module = RunSyncService,
		CacheAs = "_sync",
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "RunTransitionPolicy",
		Module = RunTransitionPolicy,
		CacheAs = "_transitionPolicy",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "StartRunCommand",
		Module = StartRunCommand,
		CacheAs = "_startRunCommand",
	},
	{
		Name = "NotifyWaveClearedCommand",
		Module = NotifyWaveClearedCommand,
		CacheAs = "_notifyWaveClearedCommand",
	},
	{
		Name = "NotifyClimaxCompleteCommand",
		Module = NotifyClimaxCompleteCommand,
		CacheAs = "_notifyClimaxCompleteCommand",
	},
	{
		Name = "NotifyCommanderDeathCommand",
		Module = NotifyCommanderDeathCommand,
		CacheAs = "_notifyCommanderDeathCommand",
	},
	{
		Name = "OnPrepTimeoutCommand",
		Module = OnPrepTimeoutCommand,
		CacheAs = "_onPrepTimeoutCommand",
	},
	{
		Name = "OnWaveTimeoutCommand",
		Module = OnWaveTimeoutCommand,
		CacheAs = "_onWaveTimeoutCommand",
	},
	{
		Name = "OnResolutionTimeoutCommand",
		Module = OnResolutionTimeoutCommand,
		CacheAs = "_onResolutionTimeoutCommand",
	},
	{
		Name = "GetRunStateQuery",
		Module = GetRunStateQuery,
		CacheAs = "_getRunStateQuery",
	},
	{
		Name = "GetWaveNumberQuery",
		Module = GetWaveNumberQuery,
		CacheAs = "_getWaveNumberQuery",
	},
}

local RunModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

--[=[
	@class RunContext
	Owns the authoritative run state machine and bridges it to other contexts.
	High-Level Flow: Register runtime modules -> hydrate sync -> react to state changes -> expose client requests.
	@server
]=]
local RunContext = Knit.CreateService({
	Name = "RunContext",
	Client = {},
	Modules = RunModules,
	ExternalServices = {
		{ Name = "MapContext", CacheAs = "_mapContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
		{ Name = "BaseContext", CacheAs = "_baseContext" },
	},
	Teardown = {
		Fields = {
			{ Field = "_playerAddedConnection", Method = "Disconnect" },
			{ Field = "_commanderDiedConnection", Method = "Disconnect" },
			{ Field = "_baseDestroyedConnection", Method = "Disconnect" },
			{ Field = "_stateChangedConnection", Method = "Disconnect" },
		},
	},
})

local RunBaseContext = BaseContext.new(RunContext)

--[=[
	@prop StateChanged RBXScriptSignal
	@within RunContext
	Fires when the authoritative run state changes.
]=]
RunContext.StateChanged = nil

-- [Initialization]

--[=[
	Initializes the run state machine, timers, and shared sync atom.
	@within RunContext
]=]
function RunContext:KnitInit()
	RunBaseContext:KnitInit()

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

-- [Private Helpers]

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
		return ModelPlus.GetPivot(marker)
	end

	return fallbackCFrame
end

-- Registers developer-only commands that map to the public run API.
function RunContext:_RegisterDeveloperLogCommands()
	-- Register the start command so developers can enter the run lifecycle from chat.
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

	-- Register the restart command so developers can return the session to lobby state.
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

	-- Register the reset command so developers can force a clean run restart.
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

	-- Register the phase-skip command so developers can fast-forward lifecycle transitions.
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

-- [Lifecycle]

--[=[
	Starts hydration for players already present and players who join later.
	@within RunContext
]=]
function RunContext:KnitStart()
	RunBaseContext:KnitStart()

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

	self._baseDestroyedConnection = GameEvents.Bus:On(GameEvents.Events.Base.BaseDestroyed, function()
		Catch(function()
			Try(self:NotifyBaseDestroyed())
			return Ok(nil)
		end, "Run:OnBaseDestroyed")
	end)
end

-- [Public API]

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
		Ensure(self._mapContext, "MissingDependency", Errors.MISSING_MAP_CONTEXT)
		Ensure(self._worldContext, "MissingDependency", Errors.MISSING_WORLD_CONTEXT)
		Ensure(self._baseContext, "MissingDependency", Errors.MISSING_BASE_CONTEXT)
		Try(self._mapContext:PrepareRuntimeMap())
		Try(self._worldContext:RefreshRuntimeGeometry())
		Try(self._baseContext:PrepareRunBase())
		-- Teleport first so the prep countdown starts from the correct phase entry point.
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
		-- Route active runs through the commander-death command so shutdown side effects stay centralized.
		if state ~= "Idle" and state ~= "RunEnd" then
			Try(self._notifyCommanderDeathCommand:Execute())
			state = self._machine:GetState()
		end

		-- Only transition back to Idle after the terminal state has settled.
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
		-- Route active runs through the commander-death command so reset preserves termination behavior.
		if state ~= "Idle" and state ~= "RunEnd" then
			Try(self._notifyCommanderDeathCommand:Execute())
			state = self._machine:GetState()
		end

		-- Only transition back to Idle after the terminal state has settled.
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

function RunContext:NotifyBaseDestroyed(): Result.Result<boolean>
	return Catch(function()
		return self._notifyCommanderDeathCommand:Execute()
	end, "Run:NotifyBaseDestroyed")
end

--[=[
	Skips the current active phase and executes its transition immediately.
	@within RunContext
	@return Result.Result<boolean> -- Whether a phase skip was performed.
]=]
function RunContext:SkipCurrentPhase(): Result.Result<boolean>
	return Catch(function()
		local state = self._machine:GetState()
		-- Skip Prep by invoking the prep timeout command, which advances into Wave.
		if state == "Prep" then
			Try(self._onPrepTimeoutCommand:Execute(self._onWaveTimeout))
			return Ok(true)
		end

		-- Skip Wave and Endless through the same resolution transition path.
		if state == "Wave" or state == "Endless" then
			Try(self._onWaveTimeoutCommand:Execute(self._onResolutionTimeout))
			return Ok(true)
		end

		-- Skip Resolution by invoking the resolution timeout command, which returns to Prep.
		if state == "Resolution" then
			Try(self._onResolutionTimeoutCommand:Execute(self._onPrepTimeout))
			return Ok(true)
		end

		-- Skip Climax by using the climax completion command so loop-entry side effects still run.
		if state == "Climax" then
			return self._notifyClimaxCompleteCommand:Execute(self._onWaveTimeout)
		end

		return Err("InvalidStateForNotify", Errors.INVALID_STATE_FOR_NOTIFY, {
			State = state,
		})
	end, "Run:SkipCurrentPhase")
end

-- [Client API]

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

-- [Private Helpers]

function RunContext:_GetPhase2EntryCFrame(): CFrame
	return _ResolveSpawnCFrame(RunTravelConfig.PHASE2_ENTRY_MARKER_NAME, RunTravelConfig.PHASE2_ENTRY_CFRAME)
end

function RunContext:_GetLobbyReturnCFrame(): CFrame
	return _ResolveSpawnCFrame(RunTravelConfig.LOBBY_RETURN_MARKER_NAME, RunTravelConfig.LOBBY_RETURN_CFRAME)
end

function RunContext:_TeleportPlayersToCFrame(targetCFrame: CFrame)
	-- Clear velocity before teleporting so players do not carry momentum across phases.
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
		Catch(function()
			if self._baseContext then
				Try(self._baseContext:CleanupBase())
			end
			if self._mapContext then
				Try(self._mapContext:CleanupRuntimeMap())
			end
			return Ok(nil)
		end, "Run:CleanupRuntimeMapOnRunEnd")

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

-- [Shutdown]

--[=[
	Cancels run lifecycle subscriptions and state listeners.
	@within RunContext
]=]
function RunContext:Destroy()
	local destroyResult = RunBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Run:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return RunContext
