--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)
local Errors = require(script.Parent.Parent.Parent.Errors)

local EnableRuntimeSyncCommand = {}
EnableRuntimeSyncCommand.__index = EnableRuntimeSyncCommand
setmetatable(EnableRuntimeSyncCommand, BaseCommand)

function EnableRuntimeSyncCommand.new()
	local self = BaseCommand.new("Entity", "EnableRuntimeSync")
	return setmetatable(self, EnableRuntimeSyncCommand)
end
function EnableRuntimeSyncCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_runtimeParticipation = "EntityRuntimeParticipationService",
	})
end

function EnableRuntimeSyncCommand:Execute(featureName: string): Result.Result<any>
	return Result.Catch(function()
		local lifecycleResult = EntityOperationSupport.RequireLifecycleStates(self._validationService, "EnableRuntimeSync", self._lifecycle:GetState(), {
			"RegisteringECS",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if self._syncContributorRegistry:GetSyncContributor(featureName) == nil then
			return Result.Err("UnknownSyncContributor", Errors.UNKNOWN_SYNC_CONTRIBUTOR, {
				FeatureName = featureName,
			})
		end

		return self._runtimeParticipation:EnableFeature("Sync", featureName)
	end, self:_Label())
end

return EnableRuntimeSyncCommand
