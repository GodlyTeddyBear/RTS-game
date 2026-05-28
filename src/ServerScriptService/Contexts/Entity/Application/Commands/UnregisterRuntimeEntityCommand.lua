--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local UnregisterRuntimeEntityCommand = {}
UnregisterRuntimeEntityCommand.__index = UnregisterRuntimeEntityCommand
setmetatable(UnregisterRuntimeEntityCommand, BaseCommand)

function UnregisterRuntimeEntityCommand.new()
	local self = BaseCommand.new("Entity", "UnregisterRuntimeEntity")
	return setmetatable(self, UnregisterRuntimeEntityCommand)
end
function UnregisterRuntimeEntityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_entityContext = "EntityContextService",
		_unregisterAIEntityCommand = "UnregisterAIEntityCommand",
		_validationService = "EntityValidationService",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_lifecycle = "EntityLifecycleStateMachine",
		_instanceBindingService = "EntityInstanceBindingService",
		_replicationService = "EntityReplicationService",
		_prepareRuntimeEntityForRemovalCommand = "PrepareRuntimeEntityForRemovalCommand",
	})
end

function UnregisterRuntimeEntityCommand:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "UnregisterRuntimeEntity", self._lifecycle:GetState(), {
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._prepareRuntimeEntityForRemovalCommand:Execute(entity, true)
	end, self:_Label())
end

return UnregisterRuntimeEntityCommand
