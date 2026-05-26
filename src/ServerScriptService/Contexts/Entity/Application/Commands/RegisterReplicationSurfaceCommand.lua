--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RegisterReplicationSurfaceCommand = {}
RegisterReplicationSurfaceCommand.__index = RegisterReplicationSurfaceCommand
setmetatable(RegisterReplicationSurfaceCommand, BaseCommand)

function RegisterReplicationSurfaceCommand.new()
	local self = BaseCommand.new("Entity", "RegisterReplicationSurface")
	return setmetatable(self, RegisterReplicationSurfaceCommand)
end
function RegisterReplicationSurfaceCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_replicationRegistry = "EntityReplicationRegistry",
		_validationService = "EntityValidationService",
	})
end

function RegisterReplicationSurfaceCommand:Execute(featureName: string, payload: any): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterReplicationSurface", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local validationResult = self._validationService:ValidateReplicationSurface(featureName, payload)
		if not validationResult.success then
			return validationResult
		end

		local registerResult = self._replicationRegistry:RegisterReplicationSurface(featureName, validationResult.value)
		if not registerResult.success then
			return registerResult
		end

		if self._lifecycle:GetState() == "ReadyForRuntimeRegistration" then
			local transitionResult = self._lifecycle:BeginRuntimeRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Result.Ok(true)
	end, self:_Label())
end

return RegisterReplicationSurfaceCommand
