--!strict

--[=[
    @class CleanupBaseCommand
    Clears the base entity, sync state, and death-emission guard at shutdown.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)

local Ok = Result.Ok

local CleanupBaseCommand = {}
CleanupBaseCommand.__index = CleanupBaseCommand
setmetatable(CleanupBaseCommand, BaseCommand)

--[=[
    Create a new cleanup command.
    @within CleanupBaseCommand
    @return CleanupBaseCommand -- Command instance.
]=]
function CleanupBaseCommand.new()
	local self = BaseCommand.new("Base", "CleanupBaseCommand")
	return setmetatable(self, CleanupBaseCommand)
end

--[=[
    Bind the base entity factory, sync service, and damage command dependencies.
    @within CleanupBaseCommand
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function CleanupBaseCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "BaseEntityFactory",
		_syncService = "BaseSyncService",
		_applyDamageCommand = "ApplyDamageBaseCommand",
	})
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
	end, self:_Label())
end

return CleanupBaseCommand
