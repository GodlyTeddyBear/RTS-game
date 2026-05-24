--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local TeamService = require(ServerStorage.Utilities.TeamService)

type TMemberHandle = TeamTypes.TMemberHandle
type TRelationship = TeamTypes.TRelationship
type TRelationshipResult = TeamTypes.TRelationshipResult
type TTeamSummary = TeamTypes.TTeamSummary

type TTeamDefinition = TeamService.TTeamDefinition
type TResolvedTeamDefinition = TeamService.TResolvedTeamDefinition

local ENEMY_TEAM_ID = "Enemy"
local PLAYER_TEAM_PREFIX = "Player:"
local PLAYER_MEMBER_PREFIX = "player:"
local MEMBER_PREFIX_BY_KIND = table.freeze({
	Player = PLAYER_MEMBER_PREFIX,
	Unit = "unit:",
	Structure = "structure:",
	Enemy = "enemy:",
})

local TeamRuntimeService = {}
TeamRuntimeService.__index = TeamRuntimeService

local function _BuildPlayerTeamId(userId: number): string
	return PLAYER_TEAM_PREFIX .. tostring(userId)
end

local function _IsPlayerTeamId(teamId: string): boolean
	return string.sub(teamId, 1, #PLAYER_TEAM_PREFIX) == PLAYER_TEAM_PREFIX
end

local function _BuildMemberKey(memberHandle: TMemberHandle): string
	local prefix = MEMBER_PREFIX_BY_KIND[memberHandle.Kind]
	assert(prefix ~= nil, "TeamRuntimeService expected a valid member-handle prefix")
	return prefix .. memberHandle.Id
end

local function _BuildTeamSummary(definition: TResolvedTeamDefinition?): TTeamSummary?
	if definition == nil then
		return nil
	end

	return {
		TeamId = definition.TeamId,
		DisplayName = definition.DisplayName,
		Metadata = definition.Metadata,
	}
end

local function _BuildPlayerTeamDefinition(userId: number): TTeamDefinition
	local idString = tostring(userId)
	return {
		TeamId = _BuildPlayerTeamId(userId),
		DisplayName = "Player " .. idString,
		Metadata = {
			UserId = userId,
			Kind = "Player",
		},
		Roblox = {
			SyncPlayers = true,
			Name = "Player_" .. idString,
			AutoAssignable = false,
		},
	}
end

local function _BuildEnemyTeamDefinition(): TTeamDefinition
	return {
		TeamId = ENEMY_TEAM_ID,
		DisplayName = "Enemy",
		Metadata = {
			Kind = "Enemy",
		},
		Roblox = {
			SyncPlayers = false,
			AutoAssignable = false,
		},
	}
end

function TeamRuntimeService.new()
	local self = setmetatable({}, TeamRuntimeService)
	self._manager = TeamService.new()
	return self
end

function TeamRuntimeService:Start()
	self:_EnsureEnemyTeam()
end

function TeamRuntimeService:EnsurePlayerTeam(player: Player): TTeamSummary
	local teamId = self:_EnsurePlayerTeamRegistered(player.UserId)
	self._manager:AssignMember(player, teamId)
	return _BuildTeamSummary(self._manager:GetTeam(teamId)) :: TTeamSummary
end

function TeamRuntimeService:AssignMemberToPlayerTeam(userId: number, memberHandle: TMemberHandle): TTeamSummary
	local teamId = self:_EnsurePlayerTeamRegistered(userId)
	self._manager:AssignMember(_BuildMemberKey(memberHandle), teamId)
	return _BuildTeamSummary(self._manager:GetTeam(teamId)) :: TTeamSummary
end

function TeamRuntimeService:AssignMemberToEnemyTeam(memberHandle: TMemberHandle): TTeamSummary
	self:_EnsureEnemyTeam()
	self._manager:AssignMember(_BuildMemberKey(memberHandle), ENEMY_TEAM_ID)
	return _BuildTeamSummary(self._manager:GetTeam(ENEMY_TEAM_ID)) :: TTeamSummary
end

function TeamRuntimeService:UnassignMember(memberHandle: TMemberHandle): boolean
	return self._manager:UnassignMember(_BuildMemberKey(memberHandle)) ~= nil
end

function TeamRuntimeService:GetPlayerTeam(userId: number): TTeamSummary?
	local player = Players:GetPlayerByUserId(userId)
	local teamDefinition = nil :: TResolvedTeamDefinition?

	if player ~= nil then
		teamDefinition = self._manager:GetMemberTeam(player)
	end

	if teamDefinition == nil then
		teamDefinition = self._manager:GetMemberTeam(PLAYER_MEMBER_PREFIX .. tostring(userId))
	end

	if teamDefinition == nil then
		teamDefinition = self._manager:GetTeam(_BuildPlayerTeamId(userId))
	end

	return _BuildTeamSummary(teamDefinition)
end

function TeamRuntimeService:GetMemberTeam(memberHandle: TMemberHandle): TTeamSummary?
	return _BuildTeamSummary(self._manager:GetMemberTeam(_BuildMemberKey(memberHandle)))
end

function TeamRuntimeService:GetRelationship(leftHandle: TMemberHandle, rightHandle: TMemberHandle): TRelationshipResult
	local leftMemberKey = _BuildMemberKey(leftHandle)
	local rightMemberKey = _BuildMemberKey(rightHandle)
	local leftTeam = self._manager:GetMemberTeam(leftMemberKey)
	local rightTeam = self._manager:GetMemberTeam(rightMemberKey)
	local relationship = self._manager:GetRelationship(leftMemberKey, rightMemberKey)

	return {
		Relationship = relationship,
		LeftTeam = _BuildTeamSummary(leftTeam),
		RightTeam = _BuildTeamSummary(rightTeam),
	}
end

function TeamRuntimeService:AreAllies(leftHandle: TMemberHandle, rightHandle: TMemberHandle): boolean
	return self._manager:AreAllies(_BuildMemberKey(leftHandle), _BuildMemberKey(rightHandle))
end

function TeamRuntimeService:Destroy()
	self._manager:Destroy()
end

function TeamRuntimeService:_EnsureEnemyTeam()
	if not self._manager:HasTeam(ENEMY_TEAM_ID) then
		self._manager:RegisterTeam(_BuildEnemyTeamDefinition())
	end
end

function TeamRuntimeService:_EnsurePlayerTeamRegistered(userId: number): string
	self:_EnsureEnemyTeam()

	local teamId = _BuildPlayerTeamId(userId)
	if not self._manager:HasTeam(teamId) then
		self._manager:RegisterTeam(_BuildPlayerTeamDefinition(userId))
	end

	self._manager:SetRelationship(teamId, ENEMY_TEAM_ID, TeamService.Relationship.Hostile)

	for _, definition in ipairs(self._manager:ListTeams()) do
		local existingTeamId = definition.TeamId
		if existingTeamId ~= teamId and _IsPlayerTeamId(existingTeamId) then
			self._manager:SetRelationship(teamId, existingTeamId, TeamService.Relationship.Neutral)
		end
	end

	return teamId
end

return TeamRuntimeService
