--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

--[=[
    @class CleanupAllExtractorsCommand
    Removes every mining extractor and resource-node entity from the mining ECS world.
    @server
]=]
local CleanupAllExtractorsCommand = {}
CleanupAllExtractorsCommand.__index = CleanupAllExtractorsCommand

-- Creates the cleanup command wrapper.
--[=[
    Creates the cleanup-all-extractors command wrapper.
    @within CleanupAllExtractorsCommand
    @return CleanupAllExtractorsCommand -- The new command instance.
]=]
function CleanupAllExtractorsCommand.new()
	return setmetatable({}, CleanupAllExtractorsCommand)
end

-- Resolves the mining entity factory during init.
--[=[
    Resolves the mining entity factory during init.
    @within CleanupAllExtractorsCommand
    @param registry any -- The dependency registry for this context.
    @param _name string -- The registered module name.
]=]
function CleanupAllExtractorsCommand:Init(registry: any, _name: string)
	self._factory = registry:Get("MiningEntityFactory")
end

-- Deletes all mining entities and flushes deferred removals.
--[=[
    Deletes all mining entities and flushes deferred removals.
    @within CleanupAllExtractorsCommand
    @return Result.Result<boolean> -- Whether the cleanup completed.
]=]
function CleanupAllExtractorsCommand:Execute(): Result.Result<boolean>
	self._factory:DeleteAll()
	self._factory:FlushPendingDeletes()
	return Ok(true)
end

return CleanupAllExtractorsCommand
