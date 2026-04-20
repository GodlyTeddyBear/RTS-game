--!strict

--[=[
    @class ClearAllCommands
    Application command that clears all active player commands for a user's adventurers.
    @server
]=]

--[[
    ClearAllCommands - Clears all player commands for a user's adventurers.

    Used during:
    - Wave transitions (before repositioning)
    - Combat end (cleanup)
    - Player disconnect

    Pattern: Application layer service
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local Ok = Result.Ok

local ClearAllCommands = {}
ClearAllCommands.__index = ClearAllCommands

export type TClearAllCommands = typeof(setmetatable({} :: {
	CommandWriteService: any,
}, ClearAllCommands))

--[=[
    Creates a new `ClearAllCommands` instance.
    @within ClearAllCommands
    @return TClearAllCommands
]=]
function ClearAllCommands.new(): TClearAllCommands
	local self = setmetatable({}, ClearAllCommands)
	self.CommandWriteService = nil :: any
	return self
end

--[=[
    Wires dependencies from the service registry.
    @within ClearAllCommands
    @param registry any -- The context-local service registry
]=]
function ClearAllCommands:Start(registry: any, _name: string)
	self.CommandWriteService = registry:Get("CommandWriteService")
end

--[=[
    Clears all active player commands for a user's adventurers.
    @within ClearAllCommands
    @param userId number -- The player's user ID
    @return Result<nil> -- Always returns `Ok(nil)`
]=]
function ClearAllCommands:Execute(userId: number): Result.Result<nil>
	self.CommandWriteService:ClearAllCommandsForUser(userId)
	MentionSuccess("PlayerCommand:ClearAllCommands:CommandWrite",
		`Cleared all commands for user {userId}`)
	return Ok(nil)
end

return ClearAllCommands
