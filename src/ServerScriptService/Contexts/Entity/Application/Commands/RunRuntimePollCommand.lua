--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RunRuntimePollCommand = {}
RunRuntimePollCommand.__index = RunRuntimePollCommand
setmetatable(RunRuntimePollCommand, BaseCommand)

function RunRuntimePollCommand.new()
	local self = BaseCommand.new("Entity", "RunRuntimePoll")
	return setmetatable(self, RunRuntimePollCommand)
end
function RunRuntimePollCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_entityContext = "EntityContextService",
		_validationService = "EntityValidationService",
		_runtimeSyncService = "EntityRuntimeSyncService",
	})
end

function RunRuntimePollCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RunRuntimePoll", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSyncService:RunRuntimePoll(self._entityContext)
	end, self:_Label())
end

return RunRuntimePollCommand