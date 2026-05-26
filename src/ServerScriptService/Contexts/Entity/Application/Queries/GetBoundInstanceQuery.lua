--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetBoundInstanceQuery = {}
GetBoundInstanceQuery.__index = GetBoundInstanceQuery
setmetatable(GetBoundInstanceQuery, BaseQuery)

function GetBoundInstanceQuery.new()
	local self = BaseQuery.new("Entity", "GetBoundInstance")
	return setmetatable(self, GetBoundInstanceQuery)
end
function GetBoundInstanceQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_instanceBindingService = "EntityInstanceBindingService",
	})
end

function GetBoundInstanceQuery:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetBoundInstance", self._lifecycle:GetState(), {
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Result.Ok(self._instanceBindingService:GetBoundInstance(entity))
	end, self:_Label())
end

return GetBoundInstanceQuery