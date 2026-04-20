--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local UnlockTypes = require(ReplicatedStorage.Contexts.Unlock.Types.UnlockTypes)

type TUnlockState = UnlockTypes.TUnlockState

local Ok, Err = Result.Ok, Result.Err

--[=[
	@class UnlockPersistenceService
	Bridges between unlock game state and `ProfileManager` for ProfileStore persistence.

	Handles deep-cloning on both read and write to ensure the in-memory atom
	state and the profile data table remain independent copies.
	@server
]=]

local UnlockPersistenceService = {}
UnlockPersistenceService.__index = UnlockPersistenceService

function UnlockPersistenceService.new()
	return setmetatable({}, UnlockPersistenceService)
end

--[=[
	@within UnlockPersistenceService
	@private
]=]
function UnlockPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
end

--- Deep clones to keep profile data and atom state independent
local function _DeepCopy(original: any): any
	if type(original) ~= "table" then
		return original
	end
	local copy = {}
	for k, v in original do
		copy[k] = _DeepCopy(v)
	end
	return copy
end

--[=[
	Loads unlock data from a player's profile, returning a deep copy safe for mutation.
	Returns `nil` if no unlock data has been saved yet.
	@within UnlockPersistenceService
	@param player Player
	@return TUnlockState?
]=]
function UnlockPersistenceService:LoadUnlockData(player: Player): TUnlockState?
	local data = self.ProfileManager:GetData(player)
	if not data or not data.Unlocks then
		return nil
	end
	return _DeepCopy(data.Unlocks)
end

--[=[
	Saves a deep copy of unlock data into the player's live profile table.

	:::note
	Writes directly into the ProfileManager data reference — this is intentional.
	ProfileStore requires in-place mutation of the profile table to persist on save.
	:::
	@within UnlockPersistenceService
	@param player Player
	@param unlockData TUnlockState -- The current unlock state to persist
	@return Result.Result<boolean>
]=]
function UnlockPersistenceService:SaveUnlockData(player: Player, unlockData: TUnlockState): Result.Result<boolean>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Err("PersistenceFailed", "No profile data", { userId = player.UserId })
	end
	-- Direct mutation of the live profile table is intentional: ProfileStore
	-- persists the profile by reference and requires in-place updates.
	data.Unlocks = _DeepCopy(unlockData)
	return Ok(true)
end

return UnlockPersistenceService
