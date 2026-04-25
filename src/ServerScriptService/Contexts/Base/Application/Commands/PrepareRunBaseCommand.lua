--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Ok = Result.Ok
local Ensure = Result.Ensure
local Try = Result.Try

local PrepareRunBaseCommand = {}
PrepareRunBaseCommand.__index = PrepareRunBaseCommand

function PrepareRunBaseCommand.new()
	return setmetatable({}, PrepareRunBaseCommand)
end

function PrepareRunBaseCommand:Init(registry: any, _name: string)
	self._entityFactory = registry:Get("BaseEntityFactory")
	self._syncService = registry:Get("BaseSyncService")
end

function PrepareRunBaseCommand:Start(registry: any, _name: string)
	self._mapContext = registry:Get("MapContext")
end

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
	end, "Base:PrepareRunBaseCommand")
end

return PrepareRunBaseCommand
