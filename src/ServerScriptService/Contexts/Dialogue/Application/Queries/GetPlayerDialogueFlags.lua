--!strict

--[=[
	@class GetPlayerDialogueFlags
	Application query to fetch all dialogue flags for a player.
	@server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local GetPlayerDialogueFlags = {}
GetPlayerDialogueFlags.__index = GetPlayerDialogueFlags

function GetPlayerDialogueFlags.new()
	return setmetatable({}, GetPlayerDialogueFlags)
end

--[=[
	Initialize service with injected dependencies from the registry.
	@within GetPlayerDialogueFlags
]=]
function GetPlayerDialogueFlags:Init(registry: any, _name: string)
	self.DialogueFlagSyncService = registry:Get("DialogueFlagSyncService")
end

--[=[
	Execute the flags query.
	@within GetPlayerDialogueFlags
	@param userId number -- The player's user ID
	@return Result<table> -- Key-value table of all dialogue flags
]=]
function GetPlayerDialogueFlags:Execute(userId: number): Result.Result<{ [string]: any }>
	local flags = self.DialogueFlagSyncService:GetPlayerFlagsReadOnly(userId) or {}
	return Ok(flags)
end

return GetPlayerDialogueFlags
