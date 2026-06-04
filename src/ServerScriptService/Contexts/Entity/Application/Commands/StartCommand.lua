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
				"Running",
			})
		if not lifecycleResult.success then
			self._startupState:SetLastStartupFailure(lifecycleResult)
			return lifecycleResult
		end

		task.defer(function()
			self._runtimeScheduler:BindSchedulerTick()
		end)
		self._startupState:ClearLastStartupFailure()
		return Result.Ok(true)
	end, self:_Label())
end

return StartCommand
