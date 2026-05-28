--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local StartCommand = {}
StartCommand.__index = StartCommand
setmetatable(StartCommand, BaseCommand)

function StartCommand.new()
	local self = BaseCommand.new("Entity", "Start")
	return setmetatable(self, StartCommand)
end

function StartCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_startupState = "EntityStartupStateService",
		_runtimeScheduler = "EntityRuntimeSchedulerService",
		_finalizeStartupCommand = "FinalizeStartupCommand",
	})
end

function StartCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local lifecycleResult =
			EntityOperationSupport.RequireLifecycleStates(self._validationService, "Start", self._lifecycle:GetState(), {
				"RegisteringECS",
				"CompilingECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
			})
		if not lifecycleResult.success then
			self._startupState:SetLastStartupFailure(lifecycleResult)
			return lifecycleResult
		end

		local finalizeResult = self._finalizeStartupCommand:Execute()
		if not finalizeResult.success then
			return finalizeResult
		end

		local runningResult =
			EntityOperationSupport.RequireLifecycleStates(self._validationService, "Start", self._lifecycle:GetState(), {
				"Running",
			})
		if not runningResult.success then
			self._startupState:SetLastStartupFailure(runningResult)
			return runningResult
		end

		self._runtimeScheduler:BindSchedulerTick()
		self._startupState:ClearLastStartupFailure()
		return Result.Ok(true)
	end, self:_Label())
end

return StartCommand
