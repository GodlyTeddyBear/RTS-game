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

local AssignMemberToPlayerTeamCommand = {}
AssignMemberToPlayerTeamCommand.__index = AssignMemberToPlayerTeamCommand
setmetatable(AssignMemberToPlayerTeamCommand, BaseCommand)

function AssignMemberToPlayerTeamCommand.new()
	local self = BaseCommand.new("Team", "AssignMemberToPlayerTeam")
	return setmetatable(self, AssignMemberToPlayerTeamCommand)
end

function AssignMemberToPlayerTeamCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function AssignMemberToPlayerTeamCommand:Execute(userId: number, memberHandle: TMemberHandle): Result.Result<TTeamSummary>
	return Result.Catch(function()
		Ensure(type(userId) == "number" and userId > 0 and math.floor(userId) == userId, "InvalidUserId", Errors.INVALID_USER_ID)
		Ensure(TeamTypes.IsMemberHandle(memberHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
		return Ok(self._runtimeService:AssignMemberToPlayerTeam(userId, memberHandle))
	end, self:_Label())
end

return AssignMemberToPlayerTeamCommand
