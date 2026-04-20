--!strict

--[=[
	@class DungeonSyncService
	Manages dungeon state synchronization via CharmSync and Blink atoms.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Dungeon.Sync.SharedAtoms)
local DungeonTypes = require(ReplicatedStorage.Contexts.Dungeon.Types.DungeonTypes)

type TDungeonState = DungeonTypes.TDungeonState
type TDungeonStatus = DungeonTypes.TDungeonStatus

local DungeonSyncService = setmetatable({}, { __index = BaseSyncService })
DungeonSyncService.__index = DungeonSyncService
DungeonSyncService.AtomKey = "dungeonState"
DungeonSyncService.BlinkEventName = "SyncDungeonState"
DungeonSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function DungeonSyncService.new()
	return setmetatable({}, DungeonSyncService)
end

--[=[
	Get the read-only dungeon state for a player.
	@within DungeonSyncService
	@param userId number -- The player's user ID
	@return DungeonState? -- The dungeon state, or nil if no active dungeon
]=]
function DungeonSyncService:GetDungeonStateReadOnly(userId: number): TDungeonState?
	return self:GetReadOnly(userId)
end

--[=[
	Check if a player has an active dungeon.
	@within DungeonSyncService
	@param userId number -- The player's user ID
	@return boolean -- Whether the player has an active dungeon
]=]
function DungeonSyncService:HasActiveDungeon(userId: number): boolean
	return self.Atom()[userId] ~= nil
end

--[=[
	Get the server-side dungeon state atom.
	@within DungeonSyncService
	@return Atom<DungeonState> -- The server atom
]=]
function DungeonSyncService:GetDungeonStateAtom()
	return self:GetAtom()
end

--[=[
	Create dungeon state for a player.
	@within DungeonSyncService
	@param userId number -- The player's user ID
	@param data DungeonState -- Initial dungeon state
]=]
function DungeonSyncService:CreateDungeon(userId: number, data: TDungeonState)
	self:LoadUserData(userId, data)
end

--[=[
	Remove all dungeon state for a player (called on cleanup or disconnect).
	@within DungeonSyncService
	@param userId number -- The player's user ID
]=]
function DungeonSyncService:RemoveDungeonState(userId: number)
	self:RemoveUserData(userId)
end

--[=[
	Update the dungeon status (e.g., "Generating", "Active", "WaveClearing", "Complete").
	@within DungeonSyncService
	@param userId number -- The player's user ID
	@param status DungeonStatus -- New status
]=]
function DungeonSyncService:SetStatus(userId: number, status: TDungeonStatus)
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].Status = status
		return updated
	end)
end

--[=[
	Update the current wave number for a dungeon.
	@within DungeonSyncService
	@param userId number -- The player's user ID
	@param wave number -- New wave number
]=]
function DungeonSyncService:SetCurrentWave(userId: number, wave: number)
	self.Atom(function(current)
		local updated = table.clone(current) -- Level 1
		updated[userId] = table.clone(updated[userId]) -- Level 2
		updated[userId].CurrentWave = wave
		return updated
	end)
end

return DungeonSyncService
