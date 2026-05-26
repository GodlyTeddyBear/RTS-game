--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)
local Errors = require(script.Parent.Parent.Parent.Errors)

local EnableRuntimeReplicationCommand = {}
EnableRuntimeReplicationCommand.__index = EnableRuntimeReplicationCommand
setmetatable(EnableRuntimeReplicationCommand, BaseCommand)

function EnableRuntimeReplicationCommand.new()
	local self = BaseCommand.new("Entity", "EnableRuntimeReplication")
	return setmetatable(self, EnableRuntimeReplicationCommand)
end
function EnableRuntimeReplicationCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_validationService = "EntityValidationService",
		_replicationRegistry = "EntityReplicationRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_entityContext = "EntityContextService",
		_replicationService = "EntityReplicationService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
	})
end

function EnableRuntimeReplicationCommand:Execute(featureName: string): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "EnableRuntimeReplication", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if self._replicationRegistry:GetReplicationSurface(featureName) == nil then
			return Result.Err("UnknownReplicationSurface", Errors.UNKNOWN_REPLICATION_SURFACE, {
				FeatureName = featureName,
			})
		end

		local enableParticipationResult = self._runtimeParticipation:EnableFeature("Replication", featureName)
		if not enableParticipationResult.success then
			return enableParticipationResult
		end

		return self._replicationService:EnableFeature(self._entityContext, featureName)
	end, self:_Label())
end

return EnableRuntimeReplicationCommand
