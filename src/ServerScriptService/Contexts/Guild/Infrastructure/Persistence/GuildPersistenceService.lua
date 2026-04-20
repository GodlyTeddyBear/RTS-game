--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdventurerTypes = require(ReplicatedStorage.Contexts.Guild.Types.AdventurerTypes)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Err = Result.Ok, Result.Err

type TAdventurer = AdventurerTypes.TAdventurer

--[=[
	@class GuildPersistenceService
	Bridges between guild game state and ProfileStore persistence via ProfileManager.
	@server
]=]

local GuildPersistenceService = {}
GuildPersistenceService.__index = GuildPersistenceService

export type TGuildPersistenceService = typeof(setmetatable({} :: { ProfileManager: any }, GuildPersistenceService))

function GuildPersistenceService.new(): TGuildPersistenceService
	local self = setmetatable({}, GuildPersistenceService)
	return self
end

--[=[
	Initialize with ProfileManager dependency.
	@within GuildPersistenceService
]=]
function GuildPersistenceService:Init(registry: any)
	self.ProfileManager = registry:Get("ProfileManager")
end

-- Recursively deep copy a table to prevent external mutations of persisted data.
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
	Load all adventurers from a player's profile (deep copy).
	@within GuildPersistenceService
	@param player Player -- The player to load data for
	@return {[string]: TAdventurer}? -- Roster keyed by adventurer ID, or nil if not present
]=]
function GuildPersistenceService:LoadAdventurers(player: Player): { [string]: TAdventurer }?
	local data = self.ProfileManager:GetData(player)
	if not data or not data.Guild then
		return nil
	end
	return _DeepCopy(data.Guild.Adventurers)
end

--[=[
	Save a single adventurer to the player's profile (deep copy).
	@within GuildPersistenceService
	@param player Player -- The player to save data for
	@param adventurerId string -- The adventurer's ID
	@param adventurerData TAdventurer -- The adventurer data to persist
	@return Result<boolean> -- Success status
	@error PersistenceFailed -- No profile data found
]=]
function GuildPersistenceService:SaveAdventurer(player: Player, adventurerId: string, adventurerData: TAdventurer): Result.Result<boolean>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Err("PersistenceFailed", "No profile data", { adventurerId = adventurerId })
	end
	data.Guild.Adventurers[adventurerId] = _DeepCopy(adventurerData)
	return Ok(true)
end

--[=[
	Save all adventurers (bulk) to the player's profile (deep copy).
	@within GuildPersistenceService
	@param player Player -- The player to save data for
	@param adventurersData {[string]: TAdventurer} -- The entire roster to persist
	@return Result<boolean> -- Success status
	@error PersistenceFailed -- No profile data found
]=]
function GuildPersistenceService:SaveAllAdventurers(player: Player, adventurersData: { [string]: TAdventurer }): Result.Result<boolean>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Err("PersistenceFailed", "No profile data")
	end
	data.Guild.Adventurers = _DeepCopy(adventurersData)
	return Ok(true)
end

--[=[
	Remove an adventurer from the player's profile.
	@within GuildPersistenceService
	@param player Player -- The player to remove data for
	@param adventurerId string -- The adventurer's ID to remove
	@return Result<boolean> -- Success status
	@error PersistenceFailed -- No profile data found
]=]
function GuildPersistenceService:RemoveAdventurer(player: Player, adventurerId: string): Result.Result<boolean>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Err("PersistenceFailed", "No profile data", { adventurerId = adventurerId })
	end
	data.Guild.Adventurers[adventurerId] = nil
	return Ok(true)
end

return GuildPersistenceService
