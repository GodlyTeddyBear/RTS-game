--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local FinalizeStartupCommand = {}
FinalizeStartupCommand.__index = FinalizeStartupCommand
setmetatable(FinalizeStartupCommand, BaseCommand)

function FinalizeStartupCommand.new()
	local self = BaseCommand.new("Entity", "FinalizeStartup")
	return setmetatable(self, FinalizeStartupCommand)
end

function FinalizeStartupCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_startupState = "EntityStartupStateService",
		_compileECSKernelCommand = "CompileECSKernelCommand",
		_finalizeRuntimeRegistrationCommand = "FinalizeRuntimeRegistrationCommand",
		_handleStartupFailureCommand = "HandleStartupFailureCommand",
	})
end

function FinalizeStartupCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(
			self._validationService,
			"FinalizeStartup",
			self._lifecycle:GetState(),
			{
				"FinalizingECSRegistration",
				"CompilingECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"Running",
			}
		)
		if not lifecycleResult.success then
			return self._handleStartupFailureCommand:Execute(lifecycleResult)
		end

		if self._lifecycle:GetState() == "Running" then
			self._startupState:ClearLastStartupFailure()
			return Result.Ok(true)
		end

		local compileResult = self._compileECSKernelCommand:Execute()
		if not compileResult.success then
			return self._handleStartupFailureCommand:Execute(compileResult)
		end

		local runtimeResult = self._finalizeRuntimeRegistrationCommand:Execute()
		if not runtimeResult.success then
			return self._handleStartupFailureCommand:Execute(runtimeResult)
		end

		self._startupState:ClearLastStartupFailure()
		return Result.Ok(true)
	end, self:_Label())
end

return FinalizeStartupCommand
