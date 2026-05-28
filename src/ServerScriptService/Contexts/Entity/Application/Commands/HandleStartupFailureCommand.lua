--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local HandleStartupFailureCommand = {}
HandleStartupFailureCommand.__index = HandleStartupFailureCommand
setmetatable(HandleStartupFailureCommand, BaseCommand)

function HandleStartupFailureCommand.new()
	local self = BaseCommand.new("Entity", "HandleStartupFailure")
	return setmetatable(self, HandleStartupFailureCommand)
end

function HandleStartupFailureCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_startupState = "EntityStartupStateService",
		_runtimeScheduler = "EntityRuntimeSchedulerService",
		_entityFactory = "EntityEntityFactory",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_replicationService = "EntityReplicationService",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_unregisterAIEntityCommand = "UnregisterAIEntityCommand",
		_entityContext = "EntityContextService",
		_preDestroyCleanupRegistry = "EntityPreDestroyCleanupRegistry",
		_shutdownRuntimeExecutionCommand = "ShutdownRuntimeExecutionCommand",
	})
end

function HandleStartupFailureCommand:Execute(failureResult: Result.Result<any>): Result.Result<any>
	return Result.Catch(function()
		self._startupState:SetLastStartupFailure(failureResult)
		self._runtimeScheduler:StopRuntimeTick()

		local currentState = self._lifecycle:GetState()
		if currentState ~= "ShuttingDown" and currentState ~= "Destroyed" then
			self._lifecycle:BeginShutdown()
		end

		if self._lifecycle:GetState() == "ShuttingDown" then
			self._shutdownRuntimeExecutionCommand:Execute()
			EntityOperationSupport.FlushPendingDestructionDuringShutdown(self._entityFactory)
			self._lifecycle:MarkDestroyed()
		end

		return failureResult
	end, self:_Label())
end

return HandleStartupFailureCommand
