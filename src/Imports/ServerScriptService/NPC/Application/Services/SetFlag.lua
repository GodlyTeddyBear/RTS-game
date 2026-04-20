--!strict

--[[
	SetFlag - Application service to validate and set a player flag

	Validates the flag name and value, then mutates the atom and persists.
	Follows the success/error tuple pattern.
]]

local Errors = require(script.Parent.Parent.Parent.Errors)
local DebugLogger = require(script.Parent.Parent.Parent.Config.DebugLogger)

local SetFlag = {}
SetFlag.__index = SetFlag

function SetFlag.new(validator: any, syncService: any, persistenceService: any)
	local self = setmetatable({}, SetFlag)

	self.Validator = validator
	self.SyncService = syncService
	self.PersistenceService = persistenceService
	self.DebugLogger = DebugLogger.new()

	return self
end

--[=[
	Sets a player flag with validation.

	@param player Player - The player instance
	@param userId number - Player's userId
	@param flagName string - The flag name
	@param flagValue boolean | string | number - The flag value
	@return (boolean, string?) - Success and optional error message
]=]
function SetFlag:Execute(player: Player, userId: number, flagName: string, flagValue: any): (boolean, string?)
	-- Validate flag name and value
	local valid, errors = self.Validator:ValidateFlag(flagName, flagValue)
	if not valid then
		warn("[NPC:SetFlag] userId:", userId, "- Validation failed:", table.concat(errors, ", "))
		return false, table.concat(errors, ", ")
	end
	self.DebugLogger:Log("SetFlag", "Validation", "userId: " .. userId .. " - Validation passed for flag: " .. flagName)

	-- Mutate atom
	self.SyncService:SetFlag(userId, flagName, flagValue)
	self.DebugLogger:Log("SetFlag", "AtomUpdate", "userId: " .. userId .. " - Set flag: " .. flagName .. " = " .. tostring(flagValue))

	-- Persist
	local saveSuccess = self.PersistenceService:SaveFlag(player, flagName, flagValue)
	if not saveSuccess then
		warn("[NPC:SetFlag] userId:", userId, "- Failed to persist flag:", flagName)
	end
	self.DebugLogger:Log("SetFlag", "Persistence", "userId: " .. userId .. " - Persisted flag: " .. flagName)

	return true, nil
end

return SetFlag
