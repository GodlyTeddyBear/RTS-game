--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local DestroyCommand = {}
DestroyCommand.__index = DestroyCommand
setmetatable(DestroyCommand, BaseCommand)

function DestroyCommand.new()
	local self = BaseCommand.new("Entity", "Destroy")
	return setmetatable(self, DestroyCommand)
end

function DestroyCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_entityFactory = "EntityEntityFactory",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_replicationService = "EntityReplicationService",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_unregisterAIEntityCommand = "UnregisterAIEntityCommand",
		_runtimeScheduler = "EntityRuntimeSchedulerService",
		_baseContext = "EntityBaseContext",
		_entityContext = "EntityContextService",
		_preDestroyCleanupRegistry = "EntityPreDestroyCleanupRegistry",
	})
end

function DestroyCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local currentState = self._lifecycle:GetState()
		if currentState ~= "ShuttingDown" and currentState ~= "Destroyed" then
			self._lifecycle:BeginShutdown()
		end

		if self._lifecycle:GetState() == "ShuttingDown" then
			self._runtimeScheduler:StopRuntimeTick()
			EntityOperationSupport.ShutdownRuntimeExecution(self)
			EntityOperationSupport.FlushPendingDestructionDuringShutdown(self._entityFactory)
			self._lifecycle:MarkDestroyed()
		end

		local destroyResult = self._baseContext:Destroy()
		if not destroyResult.success then
			return destroyResult
		end

		return Result.Ok(true)
	end, self:_Label())
end

return DestroyCommand
