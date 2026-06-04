--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

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
	self:_RequireDependency(registry, "_readService", "StructureEntityReadService")
end

function CleanupAllCommand:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
end

function CleanupAllCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		for _, entity in ipairs(self._readService:QueryPlacedEntities()) do
			Try(self._entityContext:DestroyEntity(entity))
		end
		return Ok(true)
	end, "Structure:CleanupAllCommand")
end

return CleanupAllCommand
