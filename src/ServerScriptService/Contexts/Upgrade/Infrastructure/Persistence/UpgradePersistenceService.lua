--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local UpgradeTypes = require(ReplicatedStorage.Contexts.Upgrade.Types.UpgradeTypes)

type TUpgradeLevels = UpgradeTypes.TUpgradeLevels

local Ok, Err = Result.Ok, Result.Err

--[=[
	@class UpgradePersistenceService
	Bridges between upgrade game state and `ProfileManager` for ProfileStore persistence.

	Handles deep-cloning on both read and write to ensure the in-memory atom
	state and the profile data table remain independent copies.
	@server
]=]

local UpgradePersistenceService = {}
UpgradePersistenceService.__index = UpgradePersistenceService

function UpgradePersistenceService.new()
	return setmetatable({}, UpgradePersistenceService)
end

--[=[
	@within UpgradePersistenceService
	@private
]=]
function UpgradePersistenceService:Init(registry: any, _name: string)
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
	Loads upgrade levels from a player's profile, returning a deep copy safe for mutation.
	Returns an empty table if no data exists yet.
	@within UpgradePersistenceService
	@param player Player
	@return TUpgradeLevels
]=]
function UpgradePersistenceService:LoadUpgradeData(player: Player): TUpgradeLevels
	local data = self.ProfileManager:GetData(player)
	if not data or not data.Upgrade or not data.Upgrade.Levels then
		return {}
	end
	return _DeepCopy(data.Upgrade.Levels)
end

--[=[
	Saves a deep copy of upgrade levels into the player's live profile table.

	:::note
	Writes directly into the ProfileManager data reference — this is intentional.
	ProfileStore requires in-place mutation of the profile table to persist on save.
	:::
	@within UpgradePersistenceService
	@param player Player
	@param upgradeLevels TUpgradeLevels
	@return Result.Result<boolean>
]=]
function UpgradePersistenceService:SaveUpgradeData(player: Player, upgradeLevels: TUpgradeLevels): Result.Result<boolean>
	local data = self.ProfileManager:GetData(player)
	if not data then
		return Err("PersistenceFailed", "No profile data", { userId = player.UserId })
	end
	if not data.Upgrade then
		data.Upgrade = { Levels = {} }
	end
	data.Upgrade.Levels = _DeepCopy(upgradeLevels)
	return Ok(true)
end

return UpgradePersistenceService
