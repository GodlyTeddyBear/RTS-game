--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TMemberHandle = TeamTypes.TMemberHandle
type TTeamSummary = TeamTypes.TTeamSummary

local Ensure = Result.Ensure
local Ok = Result.Ok

local AssignMemberToEnemyTeamCommand = {}
AssignMemberToEnemyTeamCommand.__index = AssignMemberToEnemyTeamCommand
setmetatable(AssignMemberToEnemyTeamCommand, BaseCommand)

function AssignMemberToEnemyTeamCommand.new()
	local self = BaseCommand.new("Team", "AssignMemberToEnemyTeam")
	return setmetatable(self, AssignMemberToEnemyTeamCommand)
end

function AssignMemberToEnemyTeamCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function AssignMemberToEnemyTeamCommand:Execute(memberHandle: TMemberHandle): Result.Result<TTeamSummary>
	return Result.Catch(function()
		Ensure(TeamTypes.IsMemberHandle(memberHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
		return Ok(self._runtimeService:AssignMemberToEnemyTeam(memberHandle))
	end, self:_Label())
end

return AssignMemberToEnemyTeamCommand
