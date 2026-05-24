--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TMemberHandle = TeamTypes.TMemberHandle

local Ensure = Result.Ensure
local Ok = Result.Ok

local AreAlliesQuery = {}
AreAlliesQuery.__index = AreAlliesQuery
setmetatable(AreAlliesQuery, BaseQuery)

function AreAlliesQuery.new()
	local self = BaseQuery.new("Team", "AreAllies")
	return setmetatable(self, AreAlliesQuery)
end

function AreAlliesQuery:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function AreAlliesQuery:Execute(leftHandle: TMemberHandle, rightHandle: TMemberHandle): Result.Result<boolean>
	Ensure(TeamTypes.IsMemberHandle(leftHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
	Ensure(TeamTypes.IsMemberHandle(rightHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
	return Ok(self._runtimeService:AreAllies(leftHandle, rightHandle))
end

return AreAlliesQuery
