--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Errors = require(script.Parent.Parent.Parent.Errors)

type TMemberHandle = TeamTypes.TMemberHandle

local Ensure = Result.Ensure
local Ok = Result.Ok

local UnassignMemberCommand = {}
UnassignMemberCommand.__index = UnassignMemberCommand
setmetatable(UnassignMemberCommand, BaseCommand)

function UnassignMemberCommand.new()
	local self = BaseCommand.new("Team", "UnassignMember")
	return setmetatable(self, UnassignMemberCommand)
end

function UnassignMemberCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_runtimeService", "TeamRuntimeService")
end

function UnassignMemberCommand:Execute(memberHandle: TMemberHandle): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(TeamTypes.IsMemberHandle(memberHandle), "InvalidMemberHandle", Errors.INVALID_MEMBER_HANDLE)
		return Ok(self._runtimeService:UnassignMember(memberHandle))
	end, self:_Label())
end

return UnassignMemberCommand
