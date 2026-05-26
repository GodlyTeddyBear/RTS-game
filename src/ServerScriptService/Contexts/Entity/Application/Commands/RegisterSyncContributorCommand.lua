--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local RegisterSyncContributorCommand = {}
RegisterSyncContributorCommand.__index = RegisterSyncContributorCommand
setmetatable(RegisterSyncContributorCommand, BaseCommand)

function RegisterSyncContributorCommand.new()
	local self = BaseCommand.new("Entity", "RegisterSyncContributor")
	return setmetatable(self, RegisterSyncContributorCommand)
end
function RegisterSyncContributorCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
	})
end

function RegisterSyncContributorCommand:Execute(featureName: string, payload: any): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "RegisterSyncContributor", self._lifecycle:GetState(), {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local validationResult = self._validationService:ValidateSyncContributor(featureName, payload)
		if not validationResult.success then
			return validationResult
		end

		local registerResult = self._syncContributorRegistry:RegisterSyncContributor(featureName, validationResult.value)
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

return RegisterSyncContributorCommand
