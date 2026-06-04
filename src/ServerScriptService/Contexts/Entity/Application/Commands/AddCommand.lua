--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local AddCommand = {}
AddCommand.__index = AddCommand
setmetatable(AddCommand, BaseCommand)

function AddCommand.new()
	local self = BaseCommand.new("Entity", "Add")
	return setmetatable(self, AddCommand)
end
function AddCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
		_worldRegistry = "EntityWorldRegistryService",
	})
end

function AddCommand:Execute(entityOrWorldName: any, keyOrEntity: any, featureNameOrKey: any?, maybeFeatureName: string?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "Add", self._lifecycle:GetState(), {
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
		local featureName = featureNameOrKey
		if type(entityOrWorldName) == "string" then
			worldName = entityOrWorldName
			entity = keyOrEntity
			key = featureNameOrKey
			featureName = maybeFeatureName
		end

		if self._worldRegistry:IsDefaultWorld(worldName) then
			return self._entityFactory:Add(entity, key, featureName)
		end

		local factoryResult = self._worldRegistry:GetEntityFactory(worldName)
		if not factoryResult.success then
			return factoryResult
		end
		return factoryResult.value:Add(entity, key, featureName)
	end, self:_Label())
end

return AddCommand
