--!strict

local GetLocalPlayerTeamQuery = {}
GetLocalPlayerTeamQuery.__index = GetLocalPlayerTeamQuery

function GetLocalPlayerTeamQuery.new(teamRemoteClient: any)
	local self = setmetatable({}, GetLocalPlayerTeamQuery)
	self._teamRemoteClient = teamRemoteClient
	return self
end

function GetLocalPlayerTeamQuery:Execute()
	return self._teamRemoteClient:GetLocalPlayerTeam()
end

return GetLocalPlayerTeamQuery
