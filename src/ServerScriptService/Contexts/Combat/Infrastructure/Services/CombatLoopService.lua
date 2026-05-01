--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)
local CombatSessionStateMachine = require(script.Parent.CombatSessionStateMachine)

local Errors = require(script.Parent.Parent.Parent.Errors)

type CombatSession = CombatTypes.CombatSession
type CombatSessionState = CombatTypes.CombatSessionState
type InternalCombatSessionState = CombatSessionState | "Inactive"

type CombatSessionRecord = {
	Machine: any,
	WaveNumber: number,
	IsEndless: boolean,
	IsPaused: boolean,
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
	return self
end

--[=[
	@within CombatLoopService
	Initializes registry dependencies for the combat loop service.
	@param _registry any -- Registry instance supplied by the context bootstrap.
	@param _name string -- Registry key used to register the service.
]=]
function CombatLoopService:Init(_registry: any, _name: string)
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
		-- Create the session machine first so the stored record always has a valid lifecycle owner.
		local machine = CombatSessionStateMachine.new()
		Try(machine:Transition("Starting"))

		-- Capture the session metadata alongside the machine so the loop can rebuild snapshots later.
		self.ActiveCombats[userId] = {
			Machine = machine,
			WaveNumber = waveNumber,
			IsEndless = isEndless,
			IsPaused = false,
		}

		return Ok("Starting")
	end, "CombatLoopService:BeginSession")
end

--[=[
	@within CombatLoopService
	Transitions one active combat session from `Starting` to `Active`.
	@param userId number -- User id that owns the combat session.
	@return Result.Result<CombatSessionState> -- New session state or a typed combat error.
]=]
function CombatLoopService:ActivateSession(userId: number): Result.Result<CombatSessionState>
	return Result.Catch(function()
		local record = self.ActiveCombats[userId]
		-- Missing sessions should surface as a typed combat error instead of a silent no-op.
		if record == nil then
			return Err("CombatSessionMissing", Errors.COMBAT_SESSION_MISSING, {
				UserId = userId,
			})
		end

		return record.Machine:Transition("Active")
	end, "CombatLoopService:ActivateSession")
end

--[=[
	@within CombatLoopService
	Transitions one combat session back to `Inactive` and removes it from the registry.
	@param userId number -- User id that owns the combat session.
	@return Result.Result<boolean> -- Whether a session was removed.
]=]
function CombatLoopService:AbortSession(userId: number): Result.Result<boolean>
	return Result.Catch(function()
		local record = self.ActiveCombats[userId]
		-- Nothing to abort if the user never entered combat.
		if record == nil then
			return Ok(false)
		end

		-- Transition out of combat before destroying the machine so cleanup sees a final state.
		Try(record.Machine:Transition("Inactive"))
		record.Machine:Destroy()
		self.ActiveCombats[userId] = nil

		return Ok(true)
	end, "CombatLoopService:AbortSession")
end

--[=[
	@within CombatLoopService
	Transitions one active combat session from `Active` to `Ending`.
	@param userId number -- User id that owns the combat session.
	@return Result.Result<CombatSessionState> -- New session state or a typed combat error.
]=]
function CombatLoopService:BeginEndingSession(userId: number): Result.Result<CombatSessionState>
	return Result.Catch(function()
		local record = self.ActiveCombats[userId]
		-- Ending only makes sense for an existing session.
		if record == nil then
			return Err("CombatSessionMissing", Errors.COMBAT_SESSION_MISSING, {
				UserId = userId,
			})
		end

		return record.Machine:Transition("Ending")
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
		-- Clearing is idempotent so callers can clean up without guarding twice.
		if record == nil then
			return Ok(false)
		end

		-- Mirror abort cleanup so the state machine exits cleanly before removal.
		Try(record.Machine:Transition("Inactive"))
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
	-- Tear down every live machine before clearing the registry so shutdown stays deterministic.
	for userId, record in pairs(self.ActiveCombats) do
		record.Machine:Destroy()
		self.ActiveCombats[userId] = nil
	end
end

return CombatLoopService
