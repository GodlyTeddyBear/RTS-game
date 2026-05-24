--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)

type TMemberHandle = TeamTypes.TMemberHandle

local GetRelationshipQuery = {}
GetRelationshipQuery.__index = GetRelationshipQuery

function GetRelationshipQuery.new(teamRemoteClient: any)
	local self = setmetatable({}, GetRelationshipQuery)
	self._teamRemoteClient = teamRemoteClient
	return self
end

function GetRelationshipQuery:Execute(leftHandle: TMemberHandle, rightHandle: TMemberHandle)
	return self._teamRemoteClient:GetRelationship(leftHandle, rightHandle)
end

return GetRelationshipQuery
