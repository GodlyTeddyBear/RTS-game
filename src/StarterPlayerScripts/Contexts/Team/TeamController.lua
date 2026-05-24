--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)

local GetLocalPlayerTeamQuery = require(script.Parent.Application.Queries.GetLocalPlayerTeamQuery)
local GetMemberTeamQuery = require(script.Parent.Application.Queries.GetMemberTeamQuery)
local GetRelationshipQuery = require(script.Parent.Application.Queries.GetRelationshipQuery)
local AreAlliesQuery = require(script.Parent.Application.Queries.AreAlliesQuery)
local TeamRemoteClient = require(script.Parent.Infrastructure.Services.TeamRemoteClient)

type TMemberHandle = TeamTypes.TMemberHandle

local TeamController = Knit.CreateController({
	Name = "TeamController",
})

function TeamController:KnitInit()
	self._teamRemoteClient = TeamRemoteClient.new()
	self._getLocalPlayerTeamQuery = GetLocalPlayerTeamQuery.new(self._teamRemoteClient)
	self._getMemberTeamQuery = GetMemberTeamQuery.new(self._teamRemoteClient)
	self._getRelationshipQuery = GetRelationshipQuery.new(self._teamRemoteClient)
	self._areAlliesQuery = AreAlliesQuery.new(self._teamRemoteClient)
end

function TeamController:KnitStart()
	self._teamRemoteClient:Start()
end

function TeamController:GetLocalPlayerTeam()
	return self._getLocalPlayerTeamQuery:Execute()
end

function TeamController:GetMemberTeam(memberHandle: TMemberHandle)
	return self._getMemberTeamQuery:Execute(memberHandle)
end

function TeamController:GetRelationship(leftHandle: TMemberHandle, rightHandle: TMemberHandle)
	return self._getRelationshipQuery:Execute(leftHandle, rightHandle)
end

function TeamController:AreAllies(leftHandle: TMemberHandle, rightHandle: TMemberHandle)
	return self._areAlliesQuery:Execute(leftHandle, rightHandle)
end

return TeamController
