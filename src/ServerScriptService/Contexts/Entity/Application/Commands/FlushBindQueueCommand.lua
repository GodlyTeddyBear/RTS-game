--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local FlushBindQueueCommand = {}
FlushBindQueueCommand.__index = FlushBindQueueCommand
setmetatable(FlushBindQueueCommand, BaseCommand)

function FlushBindQueueCommand.new()
	local self = BaseCommand.new("Entity", "FlushBindQueue")
	return setmetatable(self, FlushBindQueueCommand)
end
function FlushBindQueueCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_validationService = "EntityValidationService",
		_lifecycle = "EntityLifecycleStateMachine",
		_entityContext = "EntityContextService",
		_replicationService = "EntityReplicationService",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
	})
end

function FlushBindQueueCommand:Execute(): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "FlushBindQueue", self._lifecycle:GetState(), {
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._instanceBindingService:FlushBindQueue(self._entityContext, function(entity: number, _instance: Instance)
			EntityOperationSupport.OnRuntimeEntityBound(self._entityContext, self._runtimeParticipation, self._replicationService, entity)
		end)
	end, self:_Label())
end

return FlushBindQueueCommand