--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)
local Errors = require(script.Parent.Parent.Parent.Errors)

local QueryEntitiesQuery = {}
QueryEntitiesQuery.__index = QueryEntitiesQuery
setmetatable(QueryEntitiesQuery, BaseQuery)

function QueryEntitiesQuery.new()
	local self = BaseQuery.new("Entity", "Query")
	return setmetatable(self, QueryEntitiesQuery)
end
function QueryEntitiesQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_entityFactory = "EntityEntityFactory",
	})
end

function QueryEntitiesQuery:Execute(querySpec: any): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "Query", self._lifecycle:GetState(), {
			"RegisteringECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if type(querySpec) ~= "string" and type(querySpec) ~= "table" then
			return Result.Err("InvalidQuery", Errors.INVALID_QUERY, {
				QuerySpec = querySpec,
			})
		end

		return self._entityFactory:Query(querySpec)
	end, self:_Label())
end

return QueryEntitiesQuery
