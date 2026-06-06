--!strict

--[=[
    @class CleanupBaseCommand
    Clears the base entity, sync state, and death-emission guard at shutdown.
    @server
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local Result = require(ReplicatedStorage.Utilities.Result)
local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local BaseConfig = require(ReplicatedStorage.Contexts.Base.Config.BaseConfig)
local BASE_DEFINITION = BaseConfig.Definitions.PrimaryBase
local ECS = require(ReplicatedStorage.Utilities.ECS)

local Ok = Result.Ok

local function _ClearBaseReveal(instance: Instance)
	local _entityId, revealState = ECS.RevealBuilder.Build({
		EntityType = BaseConfig.REVEAL_ENTITY_TYPE,
		SourceId = BASE_DEFINITION.DefinitionId,
		ScopeId = BaseConfig.REVEAL_SCOPE_ID,
		Namespace = BaseConfig.REVEAL_NAMESPACE,
	})

	for attributeName in pairs(revealState.Attributes or {}) do
		instance:SetAttribute(attributeName, nil)
	end
	instance:SetAttribute("BaseId", nil)

	for tagName in pairs(revealState.Tags or {}) do
		if CollectionService:HasTag(instance, tagName) then
			CollectionService:RemoveTag(instance, tagName)
		end
	end
end

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
		_baseEntityReadService = "BaseEntityReadService",
		_syncService = "BaseSyncService",
		_applyDamageCommand = "ApplyDamageBaseCommand",
	})
end

function CleanupBaseCommand:Start(registry: any, _name: string)
	self._entityContext = registry:Get("EntityContext")
end

--[=[
    Clear the active base and reset sync state.
    @within CleanupBaseCommand
    @return Result.Result<boolean> -- Whether cleanup completed successfully.
]=]
function CleanupBaseCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local baseInstance = self._baseEntityReadService:GetMapInstance()
		local baseEntity = self._baseEntityReadService:GetActiveBaseEntity()
		if baseEntity ~= nil then
			Result.Try(self._entityContext:DestroyEntity(baseEntity))
		end
		if baseInstance ~= nil then
			_ClearBaseReveal(baseInstance)
		end

		self._syncService:ClearState()
		self._applyDamageCommand:ResetDeathEmission()
		return Ok(true)
	end, self:_Label())
end

return CleanupBaseCommand
