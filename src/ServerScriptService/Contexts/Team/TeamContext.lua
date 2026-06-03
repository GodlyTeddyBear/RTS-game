--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)

local TeamRuntimeService = require(script.Parent.Infrastructure.Services.TeamRuntimeService)
local RegisterPlayerTeamCommand = require(script.Parent.Application.Commands.RegisterPlayerTeamCommand)
local AssignMemberToPlayerTeamCommand = require(script.Parent.Application.Commands.AssignMemberToPlayerTeamCommand)
local AssignMemberToEnemyTeamCommand = require(script.Parent.Application.Commands.AssignMemberToEnemyTeamCommand)
local UnassignMemberCommand = require(script.Parent.Application.Commands.UnassignMemberCommand)
local GetPlayerTeamQuery = require(script.Parent.Application.Queries.GetPlayerTeamQuery)
local GetMemberTeamQuery = require(script.Parent.Application.Queries.GetMemberTeamQuery)
local GetRelationshipQuery = require(script.Parent.Application.Queries.GetRelationshipQuery)
local AreAlliesQuery = require(script.Parent.Application.Queries.AreAlliesQuery)

type TMemberHandle = TeamTypes.TMemberHandle
type TRelationshipResult = TeamTypes.TRelationshipResult
type TTeamSummary = TeamTypes.TTeamSummary

local Catch = Result.Catch

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "TeamRuntimeService",
		Module = TeamRuntimeService,
		CacheAs = "_runtimeService",
	},
}

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "RegisterPlayerTeamCommand",
		Module = RegisterPlayerTeamCommand,
		CacheAs = "_registerPlayerTeamCommand",
	},
	{
		Name = "AssignMemberToPlayerTeamCommand",
		Module = AssignMemberToPlayerTeamCommand,
		CacheAs = "_assignMemberToPlayerTeamCommand",
	},
	{
		Name = "AssignMemberToEnemyTeamCommand",
		Module = AssignMemberToEnemyTeamCommand,
		CacheAs = "_assignMemberToEnemyTeamCommand",
	},
	{
		Name = "UnassignMemberCommand",
		Module = UnassignMemberCommand,
		CacheAs = "_unassignMemberCommand",
	},
	{
		Name = "GetPlayerTeamQuery",
		Module = GetPlayerTeamQuery,
		CacheAs = "_getPlayerTeamQuery",
	},
	{
		Name = "GetMemberTeamQuery",
		Module = GetMemberTeamQuery,
		CacheAs = "_getMemberTeamQuery",
	},
	{
		Name = "GetRelationshipQuery",
		Module = GetRelationshipQuery,
		CacheAs = "_getRelationshipQuery",
	},
	{
		Name = "AreAlliesQuery",
		Module = AreAlliesQuery,
		CacheAs = "_areAlliesQuery",
	},
}

local TeamModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

local TeamContext = Knit.CreateService({
	Name = "TeamContext",
	Client = {},
	Modules = TeamModules,
	ExternalServices = {
		{ Name = "EntityContext", CacheAs = "_entityContext" },
	},
	Teardown = {
		Fields = {
			{ Field = "_playerAddedConnection", Method = "Disconnect" },
			{ Field = "_runtimeService", Method = "Destroy" },
		},
	},
})

local TeamBaseContext = BaseContext.new(TeamContext)

function TeamContext:KnitInit()
	TeamBaseContext:KnitInit()
	self._playerAddedConnection = nil :: RBXScriptConnection?
end

function TeamContext:KnitStart()
	TeamBaseContext:KnitStart()
	local cleanupResult = self:_RegisterCleanupOutcomes()
	if not cleanupResult.success then
		error(("TeamContext failed to register cleanup outcomes: [%s] %s"):format(
			tostring(cleanupResult.type),
			tostring(cleanupResult.message)
		))
	end

	self._playerAddedConnection = TeamBaseContext:HandleExistingAndAddedPlayers(function(player: Player)
		self:_HandlePlayerAdded(player)
	end, "_playerAddedConnection")
end

function TeamContext:_RegisterCleanupOutcomes(): Result.Result<boolean>
	return Catch(function()
		return self._entityContext:RegisterCleanupOutcomeHandler({
			OutcomeId = "TeamUnassign",
			Handle = function(context: any)
				local entity = context.Request.SourceEntity
				local identityResult = context.EntityContext:Get(entity, "Identity", "Entity")
				if not identityResult.success or type(identityResult.value) ~= "table" then
					return true
				end

				local identity = identityResult.value
				if
					not TeamTypes.IsMemberKind(identity.EntityKind)
					or type(identity.EntityId) ~= "string"
					or identity.EntityId == ""
				then
					return true
				end

				return self:UnassignMember(TeamTypes.BuildMemberHandle(identity.EntityKind, identity.EntityId))
			end,
		})
	end, "Team:RegisterCleanupOutcomes")
end

function TeamContext:RegisterPlayerTeam(player: Player): Result.Result<TTeamSummary>
	return Catch(function()
		return self._registerPlayerTeamCommand:Execute(player)
	end, "Team:RegisterPlayerTeam")
end

function TeamContext:AssignMemberToPlayerTeam(userId: number, memberHandle: TMemberHandle): Result.Result<TTeamSummary>
	return Catch(function()
		return self._assignMemberToPlayerTeamCommand:Execute(userId, memberHandle)
	end, "Team:AssignMemberToPlayerTeam")
end

function TeamContext:AssignMemberToEnemyTeam(memberHandle: TMemberHandle): Result.Result<TTeamSummary>
	return Catch(function()
		return self._assignMemberToEnemyTeamCommand:Execute(memberHandle)
	end, "Team:AssignMemberToEnemyTeam")
end

function TeamContext:UnassignMember(memberHandle: TMemberHandle): Result.Result<boolean>
	return Catch(function()
		return self._unassignMemberCommand:Execute(memberHandle)
	end, "Team:UnassignMember")
end

function TeamContext:GetPlayerTeam(userId: number): Result.Result<TTeamSummary?>
	return Catch(function()
		return self._getPlayerTeamQuery:Execute(userId)
	end, "Team:GetPlayerTeam")
end

function TeamContext:GetMemberTeam(memberHandle: TMemberHandle): Result.Result<TTeamSummary?>
	return Catch(function()
		return self._getMemberTeamQuery:Execute(memberHandle)
	end, "Team:GetMemberTeam")
end

function TeamContext:GetRelationship(
	leftHandle: TMemberHandle,
	rightHandle: TMemberHandle
): Result.Result<TRelationshipResult>
	return Catch(function()
		return self._getRelationshipQuery:Execute(leftHandle, rightHandle)
	end, "Team:GetRelationship")
end

function TeamContext:AreAllies(leftHandle: TMemberHandle, rightHandle: TMemberHandle): Result.Result<boolean>
	return Catch(function()
		return self._areAlliesQuery:Execute(leftHandle, rightHandle)
	end, "Team:AreAllies")
end

function TeamContext.Client:GetLocalPlayerTeam(player: Player): Result.Result<TTeamSummary?>
	return self.Server:GetPlayerTeam(player.UserId)
end

function TeamContext.Client:GetMemberTeam(_player: Player, memberHandle: TMemberHandle): Result.Result<TTeamSummary?>
	return self.Server:GetMemberTeam(memberHandle)
end

function TeamContext.Client:GetRelationship(
	_player: Player,
	leftHandle: TMemberHandle,
	rightHandle: TMemberHandle
): Result.Result<TRelationshipResult>
	return self.Server:GetRelationship(leftHandle, rightHandle)
end

function TeamContext.Client:AreAllies(_player: Player, leftHandle: TMemberHandle, rightHandle: TMemberHandle): Result.Result<boolean>
	return self.Server:AreAllies(leftHandle, rightHandle)
end

function TeamContext:_HandlePlayerAdded(player: Player)
	local registerResult = self:RegisterPlayerTeam(player)
	if registerResult.success then
		return
	end

	Result.MentionError("Team:PlayerAdded", "Failed to register player team", {
		UserId = player.UserId,
		CauseType = registerResult.type,
		CauseMessage = registerResult.message,
	}, registerResult.type)
end

function TeamContext:Destroy()
	local destroyResult = TeamBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Team:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return TeamContext
