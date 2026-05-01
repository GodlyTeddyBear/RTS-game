--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)
local CombatSessionStateMachine = require(script.Parent.CombatSessionStateMachine)

local Errors = require(script.Parent.Parent.Parent.Errors)

type CombatSession = CombatTypes.CombatSession
type CombatSessionLifecycleSnapshot = CombatTypes.CombatSessionLifecycleSnapshot
type CombatSessionState = CombatTypes.CombatSessionState
type InternalCombatSessionState = CombatSessionState | "Inactive"

type CombatSessionRecord = {
	Machine: any,
	WaveNumber: number,
	IsEndless: boolean,
	IsPaused: boolean,
	IsShutdownLocked: boolean,
	HasLifecycleFailure: boolean,
	FailureReason: string?,
}

local Ok = Result.Ok
local Err = Result.Err
local Try = Result.Try

--[=[
	@class CombatLoopService
	Tracks active combat sessions by user id.
	@server
]=]
local CombatLoopService = {}
CombatLoopService.__index = CombatLoopService

--[=[
	@prop ActiveCombats table
	@within CombatLoopService
	Active combat sessions keyed by user id.
]=]
--[=[
	@within CombatLoopService
	Creates a new combat loop service with an empty active-session map.
	@return CombatLoopService -- Service instance that tracks combat sessions.
]=]
function CombatLoopService.new()
	local self = setmetatable({}, CombatLoopService)
	self.ActiveCombats = {} :: { [number]: CombatSessionRecord }
	self._actorRegistryService = nil
	self._behaviorRuntimeService = nil
	return self
end

--[=[
	@within CombatLoopService
	Initializes registry dependencies for the combat loop service.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatLoopService:Init(_registry: any, _name: string)
	self._actorRegistryService = _registry:Get("CombatActorRegistryService")
	self._behaviorRuntimeService = _registry:Get("CombatBehaviorRuntimeService")
end

--[=[
	@within CombatLoopService
	Begins a combat session and transitions it from `Inactive` to `Starting`.
	@param userId number -- User id that owns the combat session.
	@param waveNumber number -- Wave number to store on the session.
	@param isEndless boolean -- Whether the session is part of endless mode.
]=]
function CombatLoopService:BeginSession(
	userId: number,
	waveNumber: number,
	isEndless: boolean
): Result.Result<CombatSessionState>
	return Result.Catch(function()
		local machine = CombatSessionStateMachine.new()
		local record: CombatSessionRecord = {
			Machine = machine,
			WaveNumber = waveNumber,
			IsEndless = isEndless,
			IsPaused = false,
			IsShutdownLocked = false,
			HasLifecycleFailure = false,
			FailureReason = nil,
		}
		self.ActiveCombats[userId] = record

		local beginResult = machine:BeginStart(self:_BuildLifecycleSnapshot(record))
		if not beginResult.success then
			record.Machine:Destroy()
			self.ActiveCombats[userId] = nil
			return beginResult
		end

		return Ok("Starting")
	end, "CombatLoopService:BeginSession")
end

--[=[
	@within CombatLoopService
	Transitions one reserved combat session from `RuntimeReady` to `Active`.
	@param userId number -- User id that owns the combat session.
	@return Result.Result<CombatSessionState> -- New session state or a typed combat error.
]=]
function CombatLoopService:ActivateSession(userId: number): Result.Result<CombatSessionState>
	return Result.Catch(function()
		local record = Try(self:_GetRecord(userId))
		return record.Machine:Activate(self:_BuildLifecycleSnapshot(record))
	end, "CombatLoopService:ActivateSession")
end

--[=[
	@within CombatLoopService
	Fails one combat session and clears it back to `Inactive`.
	@param userId number -- User id that owns the combat session.
	@return Result.Result<boolean> -- Whether a session was removed.
]=]
function CombatLoopService:AbortSession(userId: number): Result.Result<boolean>
	return Result.Catch(function()
		local record = self.ActiveCombats[userId]
		if record == nil then
			return Ok(false)
		end

		local currentState = record.Machine:GetState()
		if currentState ~= "Failed" and currentState ~= "Ending" then
			Try(self:MarkSessionFailed(userId, "SessionAborted"))
		end

		Try(self:ClearSession(userId))
		return Ok(true)
	end, "CombatLoopService:AbortSession")
end

function CombatLoopService:MarkRuntimeReady(userId: number): Result.Result<CombatSessionState>
	return Result.Catch(function()
		local record = Try(self:_GetRecord(userId))
		return record.Machine:MarkRuntimeReady(self:_BuildLifecycleSnapshot(record))
	end, "CombatLoopService:MarkRuntimeReady")
end

function CombatLoopService:MarkSessionFailed(
	userId: number,
	failureReason: string
): Result.Result<CombatSessionState>
	return Result.Catch(function()
		local record = Try(self:_GetRecord(userId))
		local previousShutdownLock = record.IsShutdownLocked
		local previousHasFailure = record.HasLifecycleFailure
		local previousFailureReason = record.FailureReason

		record.IsShutdownLocked = true
		record.HasLifecycleFailure = true
		record.FailureReason = failureReason

		local failResult = record.Machine:Fail(self:_BuildLifecycleSnapshot(record))
		if failResult.success then
			return failResult
		end

		record.IsShutdownLocked = previousShutdownLock
		record.HasLifecycleFailure = previousHasFailure
		record.FailureReason = previousFailureReason
		return failResult
	end, "CombatLoopService:MarkSessionFailed")
end

--[=[
	@within CombatLoopService
	Transitions one active combat session from `Active` to `Ending` and locks shutdown.
	@param userId number -- User id that owns the combat session.
	@return Result.Result<CombatSessionState> -- New session state or a typed combat error.
]=]
function CombatLoopService:BeginEndingSession(userId: number): Result.Result<CombatSessionState>
	return Result.Catch(function()
		local record = Try(self:_GetRecord(userId))
		local previousShutdownLock = record.IsShutdownLocked

		record.IsShutdownLocked = true
		local endingResult = record.Machine:BeginEnding(self:_BuildLifecycleSnapshot(record))
		if endingResult.success then
			return endingResult
		end

		record.IsShutdownLocked = previousShutdownLock
		return endingResult
	end, "CombatLoopService:BeginEndingSession")
end

--[=[
	@within CombatLoopService
	Clears one combat session and removes it from the registry.
	@param userId number -- User id that owns the combat session.
	@return Result.Result<boolean> -- Whether a session was removed.
]=]
function CombatLoopService:ClearSession(userId: number): Result.Result<boolean>
	return Result.Catch(function()
		local record = self.ActiveCombats[userId]
		if record == nil then
			return Ok(false)
		end

		Try(record.Machine:Clear(self:_BuildLifecycleSnapshot(record)))
		record.Machine:Destroy()
		self.ActiveCombats[userId] = nil

		return Ok(true)
	end, "CombatLoopService:ClearSession")
end

local function _BuildSession(record: CombatSessionRecord): CombatSession
	return {
		State = record.Machine:GetState(),
		WaveNumber = record.WaveNumber,
		IsEndless = record.IsEndless,
		IsPaused = record.IsPaused,
	}
end

--[=[
	@within CombatLoopService
	Marks the active combat session as paused without clearing its wave metadata.
	@param userId number -- User id whose session should be paused.
]=]
function CombatLoopService:PauseCombat(userId: number)
	local record = self.ActiveCombats[userId]
	if not record then
		return
	end

	-- Pause is a metadata toggle only; the combat machine stays alive.
	record.IsPaused = true
end

--[=[
	@within CombatLoopService
	Resumes a paused combat session for one user.
	@param userId number -- User id whose session should resume.
]=]
function CombatLoopService:ResumeCombat(userId: number)
	local record = self.ActiveCombats[userId]
	if not record then
		return
	end

	-- Resume just clears the pause flag so the existing session can run again.
	record.IsPaused = false
end

--[=[
	@within CombatLoopService
	Updates the current wave number for an active combat session.
	@param userId number -- User id whose session should update.
	@param waveNumber number -- New wave number to store on the session.
]=]
function CombatLoopService:SetCurrentWaveNumber(userId: number, waveNumber: number)
	local record = self.ActiveCombats[userId]
	if not record then
		return
	end

	-- Update the stored wave in place so snapshots and future callbacks stay aligned.
	record.WaveNumber = waveNumber
end

--[=[
	@within CombatLoopService
	Returns whether the given user currently has a combat session.
	@param userId number -- User id to check.
	@return boolean -- Whether a combat session exists for the user.
]=]
function CombatLoopService:HasSession(userId: number): boolean
	return self.ActiveCombats[userId] ~= nil
end

--[=[
	@within CombatLoopService
	Returns a cloned snapshot of one combat session.
	@param userId number -- User id whose session should be read.
	@return CombatSession? -- Cloned session data or `nil` when no session exists.
]=]
function CombatLoopService:GetSession(userId: number): CombatSession?
	local record = self.ActiveCombats[userId]
	if not record then
		return nil
	end

	-- Return a clone so callers cannot mutate the tracked session record by accident.
	return table.clone(_BuildSession(record)) :: CombatSession
end

--[=[
	@within CombatLoopService
	Returns a cloned snapshot of all combat sessions.
	@return { [number]: CombatSession } -- Cloned session map keyed by user id.
]=]
function CombatLoopService:GetSessions(): { [number]: CombatSession }
	local cloned = {}
	for userId, record in pairs(self.ActiveCombats) do
		-- Build a fresh snapshot for each user to keep the registry read-only for callers.
		cloned[userId] = _BuildSession(record)
	end
	return cloned
end

--[=[
	@within CombatLoopService
	Returns the current state for one combat session without removing it.
	@param userId number -- User id whose session should be read.
	@return InternalCombatSessionState? -- Session state or `nil` when no session exists.
]=]
function CombatLoopService:GetState(userId: number): InternalCombatSessionState?
	local record = self.ActiveCombats[userId]
	if not record then
		return nil
	end

	return record.Machine:GetState()
end

--[=[
	@within CombatLoopService
	Returns whether one session is active and not paused.
	@param userId number -- User id whose session should be checked.
	@return boolean -- Whether the combat session can run this frame.
]=]
function CombatLoopService:IsRunnable(userId: number): boolean
	local record = self.ActiveCombats[userId]
	if not record then
		return false
	end

	return record.Machine:GetState() == "Active" and not record.IsPaused
end

--[=[
	@within CombatLoopService
	Returns whether animation callbacks are allowed for one active session.
	@param userId number -- User id whose session should be checked.
	@return boolean -- Whether the combat session can accept animation callbacks.
]=]
function CombatLoopService:CanAcceptAnimationCallbacks(userId: number): boolean
	local record = self.ActiveCombats[userId]
	if not record then
		return false
	end

	return record.Machine:GetState() == "Active"
end

--[=[
	@within CombatLoopService
	Destroys all tracked sessions and clears the active combat registry.
]=]
function CombatLoopService:Destroy()
	for userId, record in pairs(self.ActiveCombats) do
		record.Machine:Destroy()
		self.ActiveCombats[userId] = nil
	end
end

function CombatLoopService:_BuildLifecycleSnapshot(record: CombatSessionRecord): CombatSessionLifecycleSnapshot
	return {
		HasSessionRecord = true,
		HasRegisteredActorTypes = self._actorRegistryService:HasActorTypes(),
		RuntimeStarted = self._actorRegistryService:IsRuntimeStarted(),
		RuntimeObjectPresent = self._behaviorRuntimeService:HasRuntimeObject(),
		QueuedActorRegistrationHealthy = self._actorRegistryService:GetPendingActorPayloadCount() == 0,
		IsShutdownLocked = record.IsShutdownLocked,
		HasLifecycleFailure = record.HasLifecycleFailure,
		FailureReason = record.FailureReason,
	}
end

function CombatLoopService:_GetRecord(userId: number): Result.Result<CombatSessionRecord>
	local record = self.ActiveCombats[userId]
	if record ~= nil then
		return Ok(record)
	end

	return Err("CombatSessionMissing", Errors.COMBAT_SESSION_MISSING, {
		UserId = userId,
	})
end

return CombatLoopService
