--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityProofRuntimeConfig = require(script.Parent.Parent.Parent.Config.EntityProofRuntimeConfig)

local FinalizeRuntimeRegistrationCommand = {}
FinalizeRuntimeRegistrationCommand.__index = FinalizeRuntimeRegistrationCommand
setmetatable(FinalizeRuntimeRegistrationCommand, BaseCommand)

function FinalizeRuntimeRegistrationCommand.new()
	local self = BaseCommand.new("Entity", "FinalizeRuntimeRegistration")
	return setmetatable(self, FinalizeRuntimeRegistrationCommand)
end

function FinalizeRuntimeRegistrationCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_validationService = "EntityValidationService",
		_instanceBindingRegistry = "EntityInstanceBindingRegistry",
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_replicationRegistry = "EntityReplicationRegistry",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_replicationService = "EntityReplicationService",
		_lifecyclePolicy = "EntityLifecyclePolicy",
		_entityContext = "EntityContextService",
	})
end

function FinalizeRuntimeRegistrationCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local currentState = self._lifecycle:GetState()
		if currentState ~= "ReadyForRuntimeRegistration" and currentState ~= "RegisteringRuntime" then
			return Result.Ok(true)
		end

		local proofRuntimeResult = self:_EnsureBuiltInOperationalProofRuntime()
		if not proofRuntimeResult.success then
			return proofRuntimeResult
		end

		local closeResult = self:_CloseRuntimeRegistries()
		if not closeResult.success then
			return closeResult
		end

		local runtimeReadyResult = self._lifecyclePolicy:ValidateRuntimeBridgeReady(
			self._instanceBindingRegistry,
			self._syncContributorRegistry,
			self._replicationRegistry
		)
		if runtimeReadyResult ~= nil then
			return runtimeReadyResult
		end

		return self._lifecycle:StartRunning()
	end, self:_Label())
end

function FinalizeRuntimeRegistrationCommand:_CloseRuntimeRegistries(): Result.Result<boolean>
	local closeBindingResult = self._instanceBindingRegistry:CloseRegistration()
	if not closeBindingResult.success then
		return closeBindingResult
	end

	local closeSyncResult = self._syncContributorRegistry:CloseRegistration()
	if not closeSyncResult.success then
		return closeSyncResult
	end

	return self._replicationRegistry:CloseRegistration()
end

function FinalizeRuntimeRegistrationCommand:_EnsureBuiltInOperationalProofRuntime(): Result.Result<boolean>
	if self._instanceBindingRegistry:GetBinding(EntityProofRuntimeConfig.FeatureName) == nil then
		local bindingResult = self._validationService:ValidateInstanceBinding(EntityProofRuntimeConfig.FeatureName, {
			FeatureName = EntityProofRuntimeConfig.FeatureName,
			ResolveAsset = function(_entityContext: any, _snapshot: any)
				local folder = Instance.new("Folder")
				folder.Name = "EntityProofRuntime"
				return folder
			end,
			BuildRevealAttributes = function(_entityContext: any, snapshot: any)
				return {
					EntityFeature = snapshot.FeatureName,
					EntityId = snapshot.Entity,
				}
			end,
			BuildName = function(_entityContext: any, snapshot: any)
				return string.format("EntityProof_%d", snapshot.Entity)
			end,
		})
		if not bindingResult.success then
			return bindingResult
		end

		local registerBindingResult = self._instanceBindingRegistry:RegisterBinding(EntityProofRuntimeConfig.FeatureName, bindingResult.value)
		if not registerBindingResult.success then
			return registerBindingResult
		end
	end

	if self._syncContributorRegistry:GetSyncContributor(EntityProofRuntimeConfig.FeatureName) == nil then
		local syncResult = self._validationService:ValidateSyncContributor(EntityProofRuntimeConfig.FeatureName, {
			FeatureName = EntityProofRuntimeConfig.FeatureName,
			QuerySyncEntities = function(_entityContext: any)
				return {}
			end,
			QueryPollEntities = function(_entityContext: any)
				return {}
			end,
		})
		if not syncResult.success then
			return syncResult
		end

		local registerSyncResult = self._syncContributorRegistry:RegisterSyncContributor(EntityProofRuntimeConfig.FeatureName, syncResult.value)
		if not registerSyncResult.success then
			return registerSyncResult
		end
	end

	if self._replicationRegistry:GetReplicationSurface(EntityProofRuntimeConfig.FeatureName) == nil then
		local replicationResult = self._validationService:ValidateReplicationSurface(EntityProofRuntimeConfig.FeatureName, {
			FeatureName = EntityProofRuntimeConfig.FeatureName,
			BuildSchema = function(_entityContext: any)
				return {
					sharedComponents = {},
					sharedTags = {},
				}
			end,
		})
		if not replicationResult.success then
			return replicationResult
		end

		local registerReplicationResult =
			self._replicationRegistry:RegisterReplicationSurface(EntityProofRuntimeConfig.FeatureName, replicationResult.value)
		if not registerReplicationResult.success then
			return registerReplicationResult
		end
	end

	local bindingEnableResult = self._runtimeParticipation:EnableFeature("Binding", EntityProofRuntimeConfig.FeatureName)
	if not bindingEnableResult.success then
		return bindingEnableResult
	end

	local replicationEnableResult =
		self._runtimeParticipation:EnableFeature("Replication", EntityProofRuntimeConfig.FeatureName)
	if not replicationEnableResult.success then
		return replicationEnableResult
	end

	return self._replicationService:EnableFeature(self._entityContext, EntityProofRuntimeConfig.FeatureName)
end

return FinalizeRuntimeRegistrationCommand
