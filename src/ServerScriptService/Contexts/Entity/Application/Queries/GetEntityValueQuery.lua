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
	})
end

function GetEntityValueQuery:Execute(entity: number, key: string, featureName: string?): Result.Result<any>
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

		return self._entityFactory:Get(entity, key, featureName)
	end, self:_Label())
end

return GetEntityValueQuery
