--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetEntityFactoryQuery = {}
GetEntityFactoryQuery.__index = GetEntityFactoryQuery
setmetatable(GetEntityFactoryQuery, BaseQuery)

function GetEntityFactoryQuery.new()
	local self = BaseQuery.new("Entity", "GetEntityFactory")
	return setmetatable(self, GetEntityFactoryQuery)
end
function GetEntityFactoryQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_entityFactory = "EntityEntityFactory",
	})
end

function GetEntityFactoryQuery:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetEntityFactory", self._lifecycle:GetState(), {
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

		return Result.Ok(self._entityFactory)
	end, self:_Label())
end

return GetEntityFactoryQuery
