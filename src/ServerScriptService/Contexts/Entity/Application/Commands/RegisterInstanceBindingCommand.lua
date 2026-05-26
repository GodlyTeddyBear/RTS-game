--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RegisterInstanceBindingCommand = {}
RegisterInstanceBindingCommand.__index = RegisterInstanceBindingCommand
setmetatable(RegisterInstanceBindingCommand, BaseCommand)

function RegisterInstanceBindingCommand.new()
	local self = BaseCommand.new("Entity", "RegisterInstanceBinding")
	return setmetatable(self, RegisterInstanceBindingCommand)
end
function RegisterInstanceBindingCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_instanceBindingRegistry = "EntityInstanceBindingRegistry",
	})
end

function RegisterInstanceBindingCommand:Execute(featureName: string, binding: any): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterInstanceBinding", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local validationResult = self._validationService:ValidateInstanceBinding(featureName, binding)
		if not validationResult.success then
			return validationResult
		end

		local registerResult = self._instanceBindingRegistry:RegisterBinding(featureName, validationResult.value)
		if not registerResult.success then
			return registerResult
		end

		if self._lifecycle:GetState() == "ReadyForRuntimeRegistration" then
			local transitionResult = self._lifecycle:BeginRuntimeRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Result.Ok(true)
	end, self:_Label())
end

return RegisterInstanceBindingCommand
