--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)

type TMemberHandle = TeamTypes.TMemberHandle

local GetMemberTeamQuery = {}
GetMemberTeamQuery.__index = GetMemberTeamQuery

function GetMemberTeamQuery.new(teamRemoteClient: any)
	local self = setmetatable({}, GetMemberTeamQuery)
	self._teamRemoteClient = teamRemoteClient
	return self
end

function GetMemberTeamQuery:Execute(memberHandle: TMemberHandle)
	return self._teamRemoteClient:GetMemberTeam(memberHandle)
end

return GetMemberTeamQuery
