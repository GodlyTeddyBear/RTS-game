--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

--[=[
    @class CleanupAllExtractorsCommand
    Removes every mining extractor and resource-node entity from the mining ECS world.
    @server
]=]
local CleanupAllExtractorsCommand = {}
CleanupAllExtractorsCommand.__index = CleanupAllExtractorsCommand
setmetatable(CleanupAllExtractorsCommand, BaseCommand)

-- Creates the cleanup command wrapper.
--[=[
    Creates the cleanup-all-extractors command wrapper.
    @within CleanupAllExtractorsCommand
    @return CleanupAllExtractorsCommand -- The new command instance.
]=]
function CleanupAllExtractorsCommand.new()
	local self = BaseCommand.new("Mining", "CleanupAllExtractorsCommand")
	return setmetatable(self, CleanupAllExtractorsCommand)
end

-- Resolves the mining entity factory during init.
--[=[
    Resolves the mining entity factory during init.
    @within CleanupAllExtractorsCommand
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function CleanupAllExtractorsCommand:Init(registry: any, _name: string)
	self:_RequireDependency(registry, "_readService", "MiningEntityReadService")
end

function CleanupAllExtractorsCommand:Start(registry: any, _name: string)
	self:_RequireDependency(registry, "_entityContext", "EntityContext")
end

-- Deletes all mining entities and flushes deferred removals.
--[=[
    Deletes all mining entities and flushes deferred removals.
    @within CleanupAllExtractorsCommand
    @return Result.Result<boolean> -- Whether the cleanup completed.
]=]
function CleanupAllExtractorsCommand:Execute(): Result.Result<boolean>
	for _, entity in ipairs(self._readService:QueryActiveExtractors()) do
		self._entityContext:MarkForDestruction(entity)
	end

	for _, entity in ipairs(self._readService:QueryResourceNodes()) do
		self._entityContext:MarkForDestruction(entity)
	end

	self._readService:Clear()
	self._entityContext:FlushDestructionQueue()
	return Ok(true)
end

return CleanupAllExtractorsCommand
