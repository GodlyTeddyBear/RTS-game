--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseQuery = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseQuery)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local GetAIRegistrationQuery = {}
GetAIRegistrationQuery.__index = GetAIRegistrationQuery
setmetatable(GetAIRegistrationQuery, BaseQuery)

function GetAIRegistrationQuery.new()
	local self = BaseQuery.new("Entity", "GetAIRegistration")
	return setmetatable(self, GetAIRegistrationQuery)
end

function GetAIRegistrationQuery:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_aiCallbackAdapterService = "EntityAICallbackAdapterService",
	})
end

function GetAIRegistrationQuery:Execute(entity: number): Result.Result<any?>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(nil, "GetAIRegistration", self._lifecycle:GetState(), {
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local ecsStateResult = self._aiCallbackAdapterService:ReadAIRegistrationRuntimeState(entity)
		local ecsState = if ecsStateResult.success then ecsStateResult.value else nil
		local transientState = self._aiEntityRegistry:GetAIRegistration(entity)
		if ecsState == nil and transientState == nil then
			return Result.Ok(nil)
		end

		return Result.Ok({
			ECS = ecsState,
			Runtime = transientState,
		})
	end, self:_Label())
end

return GetAIRegistrationQuery