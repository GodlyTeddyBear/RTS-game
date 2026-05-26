--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetAIActorHandleQuery = {}
GetAIActorHandleQuery.__index = GetAIActorHandleQuery
setmetatable(GetAIActorHandleQuery, BaseQuery)

function GetAIActorHandleQuery.new()
	local self = BaseQuery.new("Entity", "GetAIActorHandle")
	return setmetatable(self, GetAIActorHandleQuery)
end

function GetAIActorHandleQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_aiCallbackAdapterService = "EntityAICallbackAdapterService",
	})
end

function GetAIActorHandleQuery:Execute(entity: number): Result.Result<string?>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetAIActorHandle", self._lifecycle:GetState(), {
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local actorHandleResult = self._aiCallbackAdapterService:ReadAIActorHandle(entity)
		if actorHandleResult.success and actorHandleResult.value ~= nil then
			return actorHandleResult
		end

		return Result.Ok(self._aiEntityRegistry:GetAIActorHandle(entity))
	end, self:_Label())
end

return GetAIActorHandleQuery