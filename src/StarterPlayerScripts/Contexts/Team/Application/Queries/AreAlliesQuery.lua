--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)

type TMemberHandle = TeamTypes.TMemberHandle

local AreAlliesQuery = {}
AreAlliesQuery.__index = AreAlliesQuery

function AreAlliesQuery.new(teamRemoteClient: any)
	local self = setmetatable({}, AreAlliesQuery)
	self._teamRemoteClient = teamRemoteClient
	return self
end

function AreAlliesQuery:Execute(leftHandle: TMemberHandle, rightHandle: TMemberHandle)
	return self._teamRemoteClient:AreAllies(leftHandle, rightHandle)
end

return AreAlliesQuery
