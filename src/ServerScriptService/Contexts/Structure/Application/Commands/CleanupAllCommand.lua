--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local TeamTypes = require(ReplicatedStorage.Contexts.Team.Types.TeamTypes)

local Ok = Result.Ok
local Try = Result.Try

local CleanupAllCommand = {}
CleanupAllCommand.__index = CleanupAllCommand
setmetatable(CleanupAllCommand, BaseCommand)

function CleanupAllCommand.new()
	local self = BaseCommand.new("Structure", "CleanupAll")
	return setmetatable(self, CleanupAllCommand)
end

function CleanupAllCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityContext = "EntityContext",
		_readService = "StructureEntityReadService",
	})
end

function CleanupAllCommand:Start(registry: any, _name: string)
	self._teamContext = registry:Get("TeamContext")
end

function CleanupAllCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		for _, entity in ipairs(self._readService:QueryPlacedEntities()) do
			local identity = self._readService:GetIdentity(entity)
			if type(identity) == "table" and type(identity.EntityId) == "string" then
				Try(self._teamContext:UnassignMember(TeamTypes.BuildMemberHandle("Structure", identity.EntityId)))
			end
			Try(self._entityContext:DestroyEntity(entity))
		end
		return Ok(true)
	end, "Structure:CleanupAllCommand")
end

return CleanupAllCommand
