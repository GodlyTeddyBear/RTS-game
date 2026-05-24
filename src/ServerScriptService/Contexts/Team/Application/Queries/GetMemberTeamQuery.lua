--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TMemberHandle = TeamTypes.TMemberHandle
type TTeamSummary = TeamTypes.TTeamSummary

local Ensure = Result.Ensure
local Ok = Result.Ok

local GetMemberTeamQuery = {}
GetMemberTeamQuery.__index = GetMemberTeamQuery
setmetatable(GetMemberTeamQuery, BaseQuery)

function GetMemberTeamQuery.new()
	local self = BaseQuery.new("Team", "GetMemberTeam")
	return setmetatable(self, GetMemberTeamQuery)
end

function GetMemberTeamQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function GetMemberTeamQuery:Execute(memberHandle: TMemberHandle): Result.Result<TTeamSummary?>
	Ensure(TeamTypes.IsMemberHandle(memberHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
	return Ok(self._runtimeService:GetMemberTeam(memberHandle))
end

return GetMemberTeamQuery
