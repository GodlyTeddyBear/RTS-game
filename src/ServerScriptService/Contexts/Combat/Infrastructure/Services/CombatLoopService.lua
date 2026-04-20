--!strict

--[=[
	@class CombatLoopService
	Registry for active per-user combats.

	Responsibilities:
	- Track active combats (start/stop/pause/resume)
	- Provide combat metadata for the global Planck combat tick system

	The Planck ServerScheduler drives the actual tick loop — this service
	is a pure state registry with no Heartbeat connections.
	@server
]=]

local CombatLoopService = {}
CombatLoopService.__index = CombatLoopService

--[=[
	@interface TActiveCombat
	@within CombatLoopService
	.OnComplete ((status: string, deadAdventurerIds: { string }) -> ())? -- Called when combat ends
	.ZoneId string -- Zone ID for the active combat
	.CurrentWave number -- Current wave number (1-indexed)
	.TotalWaves number -- Total waves in this zone's combat
	.IsPaused boolean -- Whether the loop is paused (e.g., during transitions)
]=]

export type TActiveCombat = {
	OnComplete: ((status: string, deadAdventurerIds: { string }) -> ())?,
	ZoneId: string,
	CurrentWave: number,
	TotalWaves: number,
	IsPaused: boolean,
}

export type TCombatLoopService = typeof(setmetatable({} :: { ActiveCombats: { [number]: TActiveCombat } }, CombatLoopService))

function CombatLoopService.new(): TCombatLoopService
	local self = setmetatable({}, CombatLoopService)
	self.ActiveCombats = {} :: { [number]: TActiveCombat }
	return self
end

--[=[
	Register an active combat for a user.
	@within CombatLoopService
	@param userId number
	@param zoneId string
	@param currentWave number -- Starting wave (usually 1)
	@param totalWaves number -- Total waves for this zone
	@param onComplete ((status: string, deadAdventurerIds: { string }) -> ())? -- Called when combat ends
]=]
function CombatLoopService:StartCombat(
	userId: number,
	zoneId: string,
	currentWave: number,
	totalWaves: number,
	onComplete: ((string, { string }) -> ())?
)
	-- Cleanly stop existing combat if one exists (failsafe)
	if self.ActiveCombats[userId] then
		self:StopCombat(userId)
	end

	self.ActiveCombats[userId] = {
		OnComplete = onComplete,
		ZoneId = zoneId,
		CurrentWave = currentWave,
		TotalWaves = totalWaves,
		IsPaused = false,
	}
end

--[=[
	Remove a user's active combat.
	@within CombatLoopService
	@param userId number
]=]
function CombatLoopService:StopCombat(userId: number)
	self.ActiveCombats[userId] = nil
end

--[=[
	Pause the combat loop (e.g., during wave transitions).
	@within CombatLoopService
	@param userId number
]=]
function CombatLoopService:PauseCombat(userId: number)
	local combat = self.ActiveCombats[userId]
	if combat then
		combat.IsPaused = true
	end
end

--[=[
	Resume the combat loop after a pause.
	@within CombatLoopService
	@param userId number
]=]
function CombatLoopService:ResumeCombat(userId: number)
	local combat = self.ActiveCombats[userId]
	if combat then
		combat.IsPaused = false
	end
end

--[=[
	Update the current wave number for a user's active combat.
	@within CombatLoopService
	@param userId number
	@param wave number
]=]
function CombatLoopService:SetCurrentWave(userId: number, wave: number)
	local combat = self.ActiveCombats[userId]
	if combat then
		combat.CurrentWave = wave
	end
end

--[=[
	Get the active combat data for a user, or nil.
	@within CombatLoopService
	@param userId number
	@return TActiveCombat?
]=]
function CombatLoopService:GetActiveCombat(userId: number): TActiveCombat?
	return self.ActiveCombats[userId]
end

--[=[
	Check if a user has an active combat loop.
	@within CombatLoopService
	@param userId number
	@return boolean
]=]
function CombatLoopService:IsActive(userId: number): boolean
	return self.ActiveCombats[userId] ~= nil
end

--[=[
	Get the full ActiveCombats table.
	@within CombatLoopService
	@return { [number]: TActiveCombat } -- Map of userId → active combat
]=]
function CombatLoopService:GetActiveCombats(): { [number]: TActiveCombat }
	return self.ActiveCombats
end

return CombatLoopService
