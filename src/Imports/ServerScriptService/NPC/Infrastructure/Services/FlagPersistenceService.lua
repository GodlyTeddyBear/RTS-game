--!strict

--[[
	Flag Persistence Service

	Wraps DataManager for flag persistence operations.
	Saves/loads player flags to/from ProfileStore via DataManager.
]]

local FlagPersistenceService = {}
FlagPersistenceService.__index = FlagPersistenceService

function FlagPersistenceService.new(dataManager: any)
	local self = setmetatable({}, FlagPersistenceService)
	self.DataManager = dataManager
	return self
end

--[=[
	Saves a single flag to the player's profile.

	@param player Player - The player instance
	@param flagName string - Flag name
	@param flagValue boolean | string | number - Flag value
	@return boolean - Success
]=]
function FlagPersistenceService:SaveFlag(player: Player, flagName: string, flagValue: any): boolean
	return self.DataManager:SaveNPCFlag(player, flagName, flagValue)
end

--[=[
	Loads all flags from the player's profile.

	@param player Player - The player instance
	@return { [string]: any }? - Flags data or nil
]=]
function FlagPersistenceService:LoadFlags(player: Player): { [string]: any }?
	return self.DataManager:GetNPCFlags(player)
end

return FlagPersistenceService
