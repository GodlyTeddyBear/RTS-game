--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local HasEntityKeyQuery = {}
HasEntityKeyQuery.__index = HasEntityKeyQuery
setmetatable(HasEntityKeyQuery, BaseQuery)

function HasEntityKeyQuery.new()
	local self = BaseQuery.new("Entity", "Has")
	return setmetatable(self, HasEntityKeyQuery)
end
function HasEntityKeyQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_schemaRegistry = "EntitySchemaRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_entityFactory = "EntityEntityFactory",
		_worldRegistry = "EntityWorldRegistryService",
	})
end

function HasEntityKeyQuery:Execute(entityOrWorldName: any, keyOrEntity: any, featureNameOrKey: any?, maybeFeatureName: string?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "Has", self._lifecycle:GetState(), {
			"RegisteringECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local worldName = self._worldRegistry:GetDefaultWorldName()
		local entity = entityOrWorldName
		local key = keyOrEntity
		local featureName = featureNameOrKey
		local entityFactory = self._entityFactory
		local schemaRegistry = self._schemaRegistry
		if type(entityOrWorldName) == "string" then
			worldName = entityOrWorldName
			entity = keyOrEntity
			key = featureNameOrKey
			featureName = maybeFeatureName

			local factoryResult = self._worldRegistry:GetEntityFactory(worldName)
			if not factoryResult.success then
				return factoryResult
			end
			local schemaResult = self._worldRegistry:GetSchemaRegistry(worldName)
			if not schemaResult.success then
				return schemaResult
			end
			entityFactory = factoryResult.value
			schemaRegistry = schemaResult.value
		end

		local getResult = entityFactory:Get(entity, key, featureName)
		if not getResult.success then
			local resolvedResult = schemaRegistry:ResolveAnyId(key, featureName)
			if resolvedResult.success and resolvedResult.value.Kind == "Tag" then
				return Result.Ok(false)
			end

			return getResult
		end

		local value = getResult.value
		if type(value) == "boolean" then
			return Result.Ok(value)
		end

		return Result.Ok(value ~= nil)
	end, self:_Label())
end

return HasEntityKeyQuery
