--!strict

--[=[
    @class PrepareRunBaseCommand
    Prepares the base runtime entity and sync state before a run starts.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ReplicatedStorage.Utilities.BaseApplication.BaseCommand)
local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

local PrepareRunBaseCommand = {}
PrepareRunBaseCommand.__index = PrepareRunBaseCommand
setmetatable(PrepareRunBaseCommand, BaseCommand)

--[=[
    Create a new prepare-run command.
    @within PrepareRunBaseCommand
    @return PrepareRunBaseCommand -- Command instance.
]=]
function PrepareRunBaseCommand.new()
	local self = BaseCommand.new("Base", "PrepareRunBaseCommand")
	return setmetatable(self, PrepareRunBaseCommand)
end

--[=[
    Bind the base entity factory and sync service dependencies.
    @within PrepareRunBaseCommand
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function PrepareRunBaseCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityFactory = "BaseEntityFactory",
		_syncService = "BaseSyncService",
	})
end

--[=[
    Bind the map context dependency before execution begins.
    @within PrepareRunBaseCommand
    @param registry any -- Registry that provides dependencies.
    @param _name string -- Module name supplied by the BaseContext framework.
]=]
function PrepareRunBaseCommand:Start(registry: any, _name: string)
	self:_RequireDependency(registry, "_mapContext", "MapContext")
end

--[=[
    Create or reset the base for the active map and hydrate all players.
    @within PrepareRunBaseCommand
    @return Result.Result<boolean> -- Whether the prepare step succeeded.
]=]
function PrepareRunBaseCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		Ensure(self._mapContext ~= nil, "MissingDependency", Errors.MISSING_MAP_CONTEXT)

		local baseInstance = Try(self._mapContext:GetBaseInstance())
		Ensure(baseInstance ~= nil, "BaseInstanceNotFound", Errors.BASE_INSTANCE_NOT_FOUND)

		local baseAnchor = Try(self._mapContext:GetBaseAnchor())
		Ensure(baseAnchor ~= nil, "BaseAnchorNotFound", Errors.BASE_ANCHOR_NOT_FOUND)

		self._entityFactory:CreateOrResetBase(BaseConfig.BASE_ID, BaseConfig.MAX_HP, baseInstance, baseAnchor)
		self._syncService:SyncBaseState()
		self._syncService:HydrateAllPlayers()

		return Ok(true)
	end, self:_Label())
end

return PrepareRunBaseCommand
