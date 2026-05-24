--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TMemberHandle = TeamTypes.TMemberHandle
type TRelationshipResult = TeamTypes.TRelationshipResult

local Ensure = Result.Ensure
local Ok = Result.Ok

local GetRelationshipQuery = {}
GetRelationshipQuery.__index = GetRelationshipQuery
setmetatable(GetRelationshipQuery, BaseQuery)

function GetRelationshipQuery.new()
	local self = BaseQuery.new("Team", "GetRelationship")
	return setmetatable(self, GetRelationshipQuery)
end

function GetRelationshipQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function GetRelationshipQuery:Execute(leftHandle: TMemberHandle, rightHandle: TMemberHandle): Result.Result<TRelationshipResult>
	Ensure(TeamTypes.IsMemberHandle(leftHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
	Ensure(TeamTypes.IsMemberHandle(rightHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
	return Ok(self._runtimeService:GetRelationship(leftHandle, rightHandle))
end

return GetRelationshipQuery
