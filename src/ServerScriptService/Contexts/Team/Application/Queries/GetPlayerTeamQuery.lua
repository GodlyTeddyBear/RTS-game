--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TTeamSummary = TeamTypes.TTeamSummary

local Ensure = Result.Ensure
local Ok = Result.Ok

local GetPlayerTeamQuery = {}
GetPlayerTeamQuery.__index = GetPlayerTeamQuery
setmetatable(GetPlayerTeamQuery, BaseQuery)

function GetPlayerTeamQuery.new()
	local self = BaseQuery.new("Team", "GetPlayerTeam")
	return setmetatable(self, GetPlayerTeamQuery)
end

function GetPlayerTeamQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function GetPlayerTeamQuery:Execute(userId: number): Result.Result<TTeamSummary?>
	Ensure(type(userId) == "number" and userId > 0 and math.floor(userId) == userId, "InvalidUserId", Errors.INVALID_USER_ID)
	return Ok(self._runtimeService:GetPlayerTeam(userId))
end

return GetPlayerTeamQuery
