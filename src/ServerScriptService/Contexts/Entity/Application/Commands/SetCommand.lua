--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local SetCommand = {}
SetCommand.__index = SetCommand
setmetatable(SetCommand, BaseCommand)

function SetCommand.new()
	local self = BaseCommand.new("Entity", "Set")
	return setmetatable(self, SetCommand)
end
function SetCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
		_worldRegistry = "EntityWorldRegistryService",
	})
end

function SetCommand:Execute(entityOrWorldName: any, keyOrEntity: any, valueOrKey: any, featureNameOrValue: any?, maybeFeatureName: string?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "Set", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local worldName = self._worldRegistry:GetDefaultWorldName()
		local entity = entityOrWorldName
		local key = keyOrEntity
		local value = valueOrKey
		local featureName = featureNameOrValue
		if type(entityOrWorldName) == "string" then
			worldName = entityOrWorldName
			entity = keyOrEntity
			key = valueOrKey
			value = featureNameOrValue
			featureName = maybeFeatureName
		end

		if self._worldRegistry:IsDefaultWorld(worldName) then
			return self._entityFactory:Set(entity, key, value, featureName)
		end

		local factoryResult = self._worldRegistry:GetEntityFactory(worldName)
		if not factoryResult.success then
			return factoryResult
		end
		return factoryResult.value:Set(entity, key, value, featureName)
	end, self:_Label())
end

return SetCommand
