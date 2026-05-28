--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetFeatureComponentsQuery = {}
GetFeatureComponentsQuery.__index = GetFeatureComponentsQuery
setmetatable(GetFeatureComponentsQuery, BaseQuery)

function GetFeatureComponentsQuery.new()
	local self = BaseQuery.new("Entity", "GetFeatureComponents")
	return setmetatable(self, GetFeatureComponentsQuery)
end
function GetFeatureComponentsQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_schemaRegistry = "EntitySchemaRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
	})
end

function GetFeatureComponentsQuery:Execute(featureName: string): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetFeatureComponents", self._lifecycle:GetState(), {
			"Uninitialized",
			"RegisteringECS",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._schemaRegistry:GetFeatureComponents(featureName)
	end, self:_Label())
end

return GetFeatureComponentsQuery
