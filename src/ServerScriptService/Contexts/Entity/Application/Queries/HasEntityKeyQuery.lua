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
	})
end

function HasEntityKeyQuery:Execute(entity: number, key: string, featureName: string?): Result.Result<any>
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

		local getResult = self._entityFactory:Get(entity, key, featureName)
		if not getResult.success then
			local resolvedResult = self._schemaRegistry:ResolveAnyId(key, featureName)
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
