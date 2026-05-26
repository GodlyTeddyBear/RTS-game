--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RunRuntimeSyncCommand = {}
RunRuntimeSyncCommand.__index = RunRuntimeSyncCommand
setmetatable(RunRuntimeSyncCommand, BaseCommand)

function RunRuntimeSyncCommand.new()
	local self = BaseCommand.new("Entity", "RunRuntimeSync")
	return setmetatable(self, RunRuntimeSyncCommand)
end
function RunRuntimeSyncCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_entityContext = "EntityContextService",
		_validationService = "EntityValidationService",
		_runtimeSyncService = "EntityRuntimeSyncService",
	})
end

function RunRuntimeSyncCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RunRuntimeSync", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSyncService:RunRuntimeSync(self._entityContext)
	end, self:_Label())
end

return RunRuntimeSyncCommand