--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local MarkForDestructionCommand = {}
MarkForDestructionCommand.__index = MarkForDestructionCommand
setmetatable(MarkForDestructionCommand, BaseCommand)

function MarkForDestructionCommand.new()
	local self = BaseCommand.new("Entity", "MarkForDestruction")
	return setmetatable(self, MarkForDestructionCommand)
end
function MarkForDestructionCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_validationService = "EntityValidationService",
		_lifecycle = "EntityLifecycleStateMachine",
		_entityFactory = "EntityEntityFactory",
		_instanceBindingService = "EntityInstanceBindingService",
		_replicationService = "EntityReplicationService",
		_entityContext = "EntityContextService",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_unregisterAIEntityCommand = "UnregisterAIEntityCommand",
	})
end

function MarkForDestructionCommand:Execute(entity: number): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "MarkForDestruction", self._lifecycle:GetState(), {
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local prepareResult = EntityOperationSupport.PrepareRuntimeEntityForRemoval(self, entity, false)
		if not prepareResult.success then
			return prepareResult
		end

		return self._entityFactory:MarkEntityForDestruction(entity)
	end, self:_Label())
end

return MarkForDestructionCommand