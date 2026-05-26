--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RegisterRuntimeEntityCommand = {}
RegisterRuntimeEntityCommand.__index = RegisterRuntimeEntityCommand
setmetatable(RegisterRuntimeEntityCommand, BaseCommand)

function RegisterRuntimeEntityCommand.new()
	local self = BaseCommand.new("Entity", "RegisterRuntimeEntity")
	return setmetatable(self, RegisterRuntimeEntityCommand)
end
function RegisterRuntimeEntityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_instanceBindingService = "EntityInstanceBindingService",
		_validationService = "EntityValidationService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
	})
end

function RegisterRuntimeEntityCommand:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterRuntimeEntity", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local featureNameResult = self._runtimeParticipation:RegisterRuntimeEntity(entity)
		if not featureNameResult.success then
			return featureNameResult
		end

		if self._runtimeParticipation:IsFeatureEnabled("Binding", featureNameResult.value) then
			local queueResult = self._instanceBindingService:QueueEntityBind(entity)
			if not queueResult.success then
				self._runtimeParticipation:UnregisterRuntimeEntity(entity)
				return queueResult
			end
		end

		return Result.Ok(true)
	end, self:_Label())
end

return RegisterRuntimeEntityCommand
