--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local DestroyEntityCommand = {}
DestroyEntityCommand.__index = DestroyEntityCommand
setmetatable(DestroyEntityCommand, BaseCommand)

function DestroyEntityCommand.new()
	local self = BaseCommand.new("Entity", "DestroyEntity")
	return setmetatable(self, DestroyEntityCommand)
end

function DestroyEntityCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_entityFactory = "EntityEntityFactory",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_replicationService = "EntityReplicationService",
		_entityContext = "EntityContextService",
		_prepareRuntimeEntityForRemovalCommand = "PrepareRuntimeEntityForRemovalCommand",
	})
end

function DestroyEntityCommand:Execute(entity: number): Result.Result<boolean>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "DestroyEntity", self._lifecycle:GetState(), {
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local prepareResult = self._prepareRuntimeEntityForRemovalCommand:Execute(entity, true)
		if not prepareResult.success then
			return prepareResult
		end

		return self._entityFactory:DeleteEntityNow(entity)
	end, self:_Label())
end

return DestroyEntityCommand
