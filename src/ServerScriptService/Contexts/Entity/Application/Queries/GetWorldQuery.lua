--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetWorldQuery = {}
GetWorldQuery.__index = GetWorldQuery
setmetatable(GetWorldQuery, BaseQuery)

function GetWorldQuery.new()
	local self = BaseQuery.new("Entity", "GetWorld")
	return setmetatable(self, GetWorldQuery)
end
function GetWorldQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_worldService = "EntityECSWorldService",
	})
end

function GetWorldQuery:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetWorld", self._lifecycle:GetState(), {
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

		return Result.Ok(self._worldService:GetWorld())
	end, self:_Label())
end

return GetWorldQuery
