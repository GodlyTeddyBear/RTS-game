--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok, Try, fromNilable = Result.Ok, Result.Try, Result.fromNilable

--[=[
	@class CommissionPersistenceService
	Bridges commission in-memory state to ProfileStore persistence via ProfileManager.
	@server
]=]
local CommissionPersistenceService = {}
CommissionPersistenceService.__index = CommissionPersistenceService

--[=[
	Construct a new CommissionPersistenceService.
	@within CommissionPersistenceService
	@return CommissionPersistenceService
]=]
function CommissionPersistenceService.new()
	local self = setmetatable({}, CommissionPersistenceService)
	return self
end

--[=[
	Wire registry dependencies (called by Registry:InitAll).
	@within CommissionPersistenceService
	@param registry any -- The context registry
]=]
function CommissionPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
end

--- Deep copy utility to prevent external mutation
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
	Load commission data from a player's profile, returning a deep copy or `nil` if absent.
	@within CommissionPersistenceService
	@param player Player -- The player whose data to load
	@return any? -- Deep-copied commission data, or `nil` if not present
]=]
function CommissionPersistenceService:LoadCommissionData(player: Player): any?
	local data = self.ProfileManager:GetData(player)
	if not data or not data.Commission then
		return nil
	end
	return _DeepCopy(data.Commission)
end

--[=[
	Save commission data into the player's profile as a deep copy.
	@within CommissionPersistenceService
	@param player Player -- The player whose profile to update
	@param commissionData any -- The commission state to persist
	@return Result<boolean> -- `Ok(true)` on success, `Err` if the profile is unavailable
]=]
function CommissionPersistenceService:SaveCommissionData(player: Player, commissionData: any): Result.Result<boolean>
	local data = Try(fromNilable(
		self.ProfileManager:GetData(player),
		"PersistenceFailed",
		"No profile data",
		{ userId = player.UserId }
	))
	data.Commission = _DeepCopy(commissionData)
	return Ok(true)
end

return CommissionPersistenceService
