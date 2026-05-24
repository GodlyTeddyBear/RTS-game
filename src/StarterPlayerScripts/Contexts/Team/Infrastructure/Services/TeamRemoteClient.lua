--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)

type TMemberHandle = TeamTypes.TMemberHandle

local TeamRemoteClient = {}
TeamRemoteClient.__index = TeamRemoteClient

function TeamRemoteClient.new()
	local self = setmetatable({}, TeamRemoteClient)
	self._teamContext = nil
	return self
end

function TeamRemoteClient:Start()
	self._teamContext = Knit.GetService("TeamContext")
end

function TeamRemoteClient:GetLocalPlayerTeam()
	assert(self._teamContext ~= nil, "TeamRemoteClient missing TeamContext")
	return self._teamContext:GetLocalPlayerTeam()
end

function TeamRemoteClient:GetMemberTeam(memberHandle: TMemberHandle)
	assert(self._teamContext ~= nil, "TeamRemoteClient missing TeamContext")
	return self._teamContext:GetMemberTeam(memberHandle)
end

function TeamRemoteClient:GetRelationship(leftHandle: TMemberHandle, rightHandle: TMemberHandle)
	assert(self._teamContext ~= nil, "TeamRemoteClient missing TeamContext")
	return self._teamContext:GetRelationship(leftHandle, rightHandle)
end

function TeamRemoteClient:AreAllies(leftHandle: TMemberHandle, rightHandle: TMemberHandle)
	assert(self._teamContext ~= nil, "TeamRemoteClient missing TeamContext")
	return self._teamContext:AreAllies(leftHandle, rightHandle)
end

return TeamRemoteClient
