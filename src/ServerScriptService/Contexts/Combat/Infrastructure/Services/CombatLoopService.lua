--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

type CombatSession = CombatTypes.CombatSession

--[=[
	@class CombatLoopService
	Tracks active combat sessions by user id.
	@server
]=]
--[=[
	@class CombatLoopService
	Tracks active combat sessions by user id.
	@server
]=]
local CombatLoopService = {}
CombatLoopService.__index = CombatLoopService

-- Creates a new combat loop service with an empty active-session map.
function CombatLoopService.new()
	local self = setmetatable({}, CombatLoopService)
	self.ActiveCombats = {} :: { [number]: CombatSession }
	return self
end

-- Initializes registry dependencies for the combat loop service.
function CombatLoopService:Init(_registry: any, _name: string)
end

-- Starts or replaces the active combat session for one user.
function CombatLoopService:StartCombat(userId: number, waveNumber: number, isEndless: boolean)
	self.ActiveCombats[userId] = {
		WaveNumber = waveNumber,
		IsEndless = isEndless,
		IsPaused = false,
	}
end

-- Stops the active combat session for one user.
function CombatLoopService:StopCombat(userId: number)
	self.ActiveCombats[userId] = nil
end

-- Marks the active combat session as paused without clearing its wave metadata.
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

-- Resumes a paused combat session for one user.
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

-- Updates the current wave number for an active combat session.
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

-- Returns whether the given user currently has an active combat session.
function CombatLoopService:IsActive(userId: number): boolean
	return self.ActiveCombats[userId] ~= nil
end

-- Returns a cloned snapshot of one active combat session.
function CombatLoopService:GetActiveCombat(userId: number): CombatSession?
	local activeCombat = self.ActiveCombats[userId]
	if not activeCombat then
		return nil
	end
	return table.clone(activeCombat) :: CombatSession
end

-- Returns a cloned snapshot of all active combat sessions.
function CombatLoopService:GetActiveCombats(): { [number]: CombatSession }
	local cloned = {}
	for userId, activeCombat in pairs(self.ActiveCombats) do
		cloned[userId] = table.clone(activeCombat)
	end
	return cloned
end

return CombatLoopService
