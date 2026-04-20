--!strict

--[=[
	@class DialogueFlagPersistenceService
	Infrastructure service handling dialogue flag persistence to and from player profiles.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok
local Err = Result.Err

local DialogueFlagPersistenceService = {}
DialogueFlagPersistenceService.__index = DialogueFlagPersistenceService

export type TDialogueFlagPersistenceService = typeof(setmetatable({} :: {
	ProfileManager: any,
}, DialogueFlagPersistenceService))

-- Create a deep copy of a table (or return scalars unchanged) to prevent accidental external mutations.
local function _DeepCopy(original: any): any
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for key, value in original do
		copy[key] = _DeepCopy(value)
	end
	return copy
end

function DialogueFlagPersistenceService.new(): TDialogueFlagPersistenceService
	return setmetatable({}, DialogueFlagPersistenceService)
end

--[=[
	Initialize service with injected dependencies from the registry.
	@within DialogueFlagPersistenceService
]=]
function DialogueFlagPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
end

--[=[
	Load dialogue flags from a player's profile. Returns a deep copy to prevent external mutations.
	@within DialogueFlagPersistenceService
	@param player Player -- The player whose flags to load
	@return table? -- Deep copy of flags, or nil if none exist
]=]
function DialogueFlagPersistenceService:LoadFlags(player: Player): { [string]: any }?
	local profileData = self.ProfileManager:GetData(player)
	if not profileData or not profileData.Flags then
		return nil
	end

	return _DeepCopy(profileData.Flags)
end

--[=[
	Persist dialogue flags to a player's profile. Stores a deep copy to prevent later mutations of the input table.
	@within DialogueFlagPersistenceService
	@param player Player -- The player whose flags to save
	@param flags table -- Key-value table of flags to persist
	@return Result<boolean> -- Success if saved, error otherwise
]=]
function DialogueFlagPersistenceService:SaveFlags(player: Player, flags: { [string]: any }): Result.Result<boolean>
	local profileData = self.ProfileManager:GetData(player)
	if not profileData then
		return Err("PersistenceFailed", "No profile data", { userId = player.UserId })
	end

	profileData.Flags = _DeepCopy(flags)
	return Ok(true)
end

return DialogueFlagPersistenceService
