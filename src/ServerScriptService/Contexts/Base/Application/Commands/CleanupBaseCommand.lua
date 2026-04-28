--!strict

--[=[
    @class CleanupBaseCommand
    Clears the base entity, sync state, and death-emission guard at shutdown.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)

local Ok = Result.Ok

local CleanupBaseCommand = {}
CleanupBaseCommand.__index = CleanupBaseCommand

--[=[
    Create a new cleanup command.
    @within CleanupBaseCommand
    @return CleanupBaseCommand -- Command instance.
]=]
function CleanupBaseCommand.new()
	return setmetatable({}, CleanupBaseCommand)
end

--[=[
    Bind the base entity factory, sync service, and damage command dependencies.
    @within CleanupBaseCommand
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function CleanupBaseCommand:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("BaseEntityFactory")
	self._syncService = registry:Get("BaseSyncService")
	self._applyDamageCommand = registry:Get("ApplyDamageBaseCommand")
end

--[=[
    Clear the active base and reset sync state.
    @within CleanupBaseCommand
    @return Result.Result<boolean> -- Whether cleanup completed successfully.
]=]
function CleanupBaseCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		self._entityFactory:ClearBase()
		self._syncService:ClearState()
		self._applyDamageCommand:ResetDeathEmission()
		return Ok(true)
	end, "Base:CleanupBaseCommand")
end

return CleanupBaseCommand
