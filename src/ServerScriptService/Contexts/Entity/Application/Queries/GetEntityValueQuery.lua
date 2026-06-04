--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetEntityValueQuery = {}
GetEntityValueQuery.__index = GetEntityValueQuery
setmetatable(GetEntityValueQuery, BaseQuery)

function GetEntityValueQuery.new()
	local self = BaseQuery.new("Entity", "Get")
	return setmetatable(self, GetEntityValueQuery)
end
function GetEntityValueQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_entityFactory = "EntityEntityFactory",
		_worldRegistry = "EntityWorldRegistryService",
	})
end

function GetEntityValueQuery:Execute(entityOrWorldName: any, keyOrEntity: any, featureNameOrKey: any?, maybeFeatureName: string?): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "Get", self._lifecycle:GetState(), {
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
		if type(entityOrWorldName) == "string" then
			worldName = entityOrWorldName
			entity = keyOrEntity
			key = featureNameOrKey
			featureName = maybeFeatureName
		end

		if self._worldRegistry:IsDefaultWorld(worldName) then
			return self._entityFactory:Get(entity, key, featureName)
		end

		local factoryResult = self._worldRegistry:GetEntityFactory(worldName)
		if not factoryResult.success then
			return factoryResult
		end
		return factoryResult.value:Get(entity, key, featureName)
	end, self:_Label())
end

return GetEntityValueQuery
