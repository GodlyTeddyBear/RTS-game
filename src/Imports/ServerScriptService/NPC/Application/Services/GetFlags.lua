--!strict

--[[
	GetFlags - Application service to read player flags

	Returns all flags for a player from the sync atom (deep cloned).
	Follows the success/error tuple pattern.
]]

local GetFlags = {}
GetFlags.__index = GetFlags

function GetFlags.new(syncService: any)
	local self = setmetatable({}, GetFlags)
	self.SyncService = syncService
	return self
end

--[=[
	Gets all flags for a player.

	@param userId number - Player's userId
	@return (boolean, { [string]: any } | string) - Success and flags or error
]=]
function GetFlags:Execute(userId: number): (boolean, { [string]: any } | string)
	if not userId or userId <= 0 then
		return false, "Invalid userId"
	end

	local flags = self.SyncService:GetPlayerFlagsReadOnly(userId)
	return true, flags or {}
end

return GetFlags
