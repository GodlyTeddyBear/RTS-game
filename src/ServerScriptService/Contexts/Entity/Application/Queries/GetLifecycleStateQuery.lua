--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetLifecycleStateQuery = {}
GetLifecycleStateQuery.__index = GetLifecycleStateQuery
setmetatable(GetLifecycleStateQuery, BaseQuery)

function GetLifecycleStateQuery.new()
	local self = BaseQuery.new("Entity", "GetLifecycleState")
	return setmetatable(self, GetLifecycleStateQuery)
end
function GetLifecycleStateQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
	})
end

function GetLifecycleStateQuery:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetLifecycleState", self._lifecycle:GetState(), {
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

		return Result.Ok(self._lifecycle:GetState())
	end, self:_Label())
end

return GetLifecycleStateQuery
