--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetBoundEntityQuery = {}
GetBoundEntityQuery.__index = GetBoundEntityQuery
setmetatable(GetBoundEntityQuery, BaseQuery)

function GetBoundEntityQuery.new()
	local self = BaseQuery.new("Entity", "GetBoundEntity")
	return setmetatable(self, GetBoundEntityQuery)
end
function GetBoundEntityQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_instanceBindingService = "EntityInstanceBindingService",
	})
end

function GetBoundEntityQuery:Execute(instance: Instance): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetBoundEntity", self._lifecycle:GetState(), {
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Result.Ok(self._instanceBindingService:GetBoundEntity(instance))
	end, self:_Label())
end

return GetBoundEntityQuery