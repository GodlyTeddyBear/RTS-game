--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)
local Errors = require(script.Parent.Parent.Parent.Errors)

local EnableRuntimeBindingCommand = {}
EnableRuntimeBindingCommand.__index = EnableRuntimeBindingCommand
setmetatable(EnableRuntimeBindingCommand, BaseCommand)

function EnableRuntimeBindingCommand.new()
	local self = BaseCommand.new("Entity", "EnableRuntimeBinding")
	return setmetatable(self, EnableRuntimeBindingCommand)
end
function EnableRuntimeBindingCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_instanceBindingRegistry = "EntityInstanceBindingRegistry",
	})
end

function EnableRuntimeBindingCommand:Execute(featureName: string): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "EnableRuntimeBinding", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if self._instanceBindingRegistry:GetBinding(featureName) == nil then
			return Result.Err("UnknownInstanceBinding", Errors.UNKNOWN_INSTANCE_BINDING, {
				FeatureName = featureName,
			})
		end

		return self._runtimeParticipation:EnableFeature("Binding", featureName)
	end, self:_Label())
end

return EnableRuntimeBindingCommand
