--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

type CombatSession = CombatTypes.CombatSession

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
	self.ActiveCombats = {} :: { [number]: CombatSession }
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
	Starts or replaces the active combat session for one user.
	@param userId number -- User id that owns the combat session.
	@param waveNumber number -- Wave number to store on the session.
	@param isEndless boolean -- Whether the session is part of endless mode.
]=]
function CombatLoopService:StartCombat(userId: number, waveNumber: number, isEndless: boolean)
	self.ActiveCombats[userId] = {
		WaveNumber = waveNumber,
		IsEndless = isEndless,
		IsPaused = false,
	}
end

--[=[
	@within CombatLoopService
	Stops the active combat session for one user.
	@param userId number -- User id whose session should end.
]=]
function CombatLoopService:StopCombat(userId: number)
	self.ActiveCombats[userId] = nil
end

--[=[
	@within CombatLoopService
	Marks the active combat session as paused without clearing its wave metadata.
	@param userId number -- User id whose session should be paused.
]=]
function CombatLoopService:PauseCombat(userId: number)
	local activeCombat = self.ActiveCombats[userId]
	if not activeCombat then
		return
	end
	self.ActiveCombats[userId] = {
		WaveNumber = activeCombat.WaveNumber,
		IsEndless = activeCombat.IsEndless,
		IsPaused = true,
	}
end

--[=[
	@within CombatLoopService
	Resumes a paused combat session for one user.
	@param userId number -- User id whose session should resume.
]=]
function CombatLoopService:ResumeCombat(userId: number)
	local activeCombat = self.ActiveCombats[userId]
	if not activeCombat then
		return
	end
	self.ActiveCombats[userId] = {
		WaveNumber = activeCombat.WaveNumber,
		IsEndless = activeCombat.IsEndless,
		IsPaused = false,
	}
end

--[=[
	@within CombatLoopService
	Updates the current wave number for an active combat session.
	@param userId number -- User id whose session should update.
	@param waveNumber number -- New wave number to store on the session.
]=]
function CombatLoopService:SetCurrentWaveNumber(userId: number, waveNumber: number)
	local activeCombat = self.ActiveCombats[userId]
	if not activeCombat then
		return
	end
	self.ActiveCombats[userId] = {
		WaveNumber = waveNumber,
		IsEndless = activeCombat.IsEndless,
		IsPaused = activeCombat.IsPaused,
	}
end

--[=[
	@within CombatLoopService
	Returns whether the given user currently has an active combat session.
	@param userId number -- User id to check.
	@return boolean -- Whether a combat session exists for the user.
]=]
function CombatLoopService:IsActive(userId: number): boolean
	return self.ActiveCombats[userId] ~= nil
end

--[=[
	@within CombatLoopService
	Returns a cloned snapshot of one active combat session.
	@param userId number -- User id whose session should be read.
	@return CombatSession? -- Cloned session data or `nil` when no session exists.
]=]
function CombatLoopService:GetActiveCombat(userId: number): CombatSession?
	local activeCombat = self.ActiveCombats[userId]
	if not activeCombat then
		return nil
	end
	return table.clone(activeCombat) :: CombatSession
end

--[=[
	@within CombatLoopService
	Returns a cloned snapshot of all active combat sessions.
	@return { [number]: CombatSession } -- Cloned active-session map keyed by user id.
]=]
function CombatLoopService:GetActiveCombats(): { [number]: CombatSession }
	local cloned = {}
	for userId, activeCombat in pairs(self.ActiveCombats) do
		cloned[userId] = table.clone(activeCombat)
	end
	return cloned
end

return CombatLoopService
