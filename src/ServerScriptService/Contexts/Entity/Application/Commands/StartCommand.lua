--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseCommand = require(ServerStorage.Utilities.ContextUtilities.BaseApplication.BaseCommand)
local Result = require(ReplicatedStorage.Utilities.Result)
local EntityProofRuntimeConfig = require(script.Parent.Parent.Parent.Config.EntityProofRuntimeConfig)
local EntityOperationSupport = require(script.Parent.Parent.Support.EntityOperationSupport)

local StartCommand = {}
StartCommand.__index = StartCommand
setmetatable(StartCommand, BaseCommand)

function StartCommand.new()
	local self = BaseCommand.new("Entity", "Start")
	return setmetatable(self, StartCommand)
end

function StartCommand:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_schemaRegistry = "EntitySchemaRegistry",
		_systemRegistry = "EntitySystemRegistry",
		_entityFactory = "EntityEntityFactory",
		_instanceBindingRegistry = "EntityInstanceBindingRegistry",
		_instanceBindingService = "EntityInstanceBindingService",
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_replicationRegistry = "EntityReplicationRegistry",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_replicationService = "EntityReplicationService",
		_aiActorTypeRegistry = "EntityAIActorTypeRegistry",
		_combatAIRuntimeBridge = "EntityCombatAIRuntimeBridge",
		_unregisterAIEntityCommand = "UnregisterAIEntityCommand",
		_lifecyclePolicy = "EntityLifecyclePolicy",
		_validationService = "EntityValidationService",
		_startupState = "EntityStartupStateService",
		_runtimeScheduler = "EntityRuntimeSchedulerService",
		_entityContext = "EntityContextService",
	})
end

function StartCommand:Execute(): Result.Result<boolean>
	return Result.Catch(function()
		local function fail(result: Result.Result<any>): Result.Result<any>
			self._startupState:SetLastStartupFailure(result)
			self:_HandleStartupFailure()
			return result
		end

		local currentState = self._lifecycle:GetState()
		if currentState == "RegisteringECS" then
			local beginResult = self:_BeginECSCompile()
			if not beginResult.success then
				return fail(beginResult)
			end
			currentState = self._lifecycle:GetState()
		end

		if currentState == "CompilingECS" then
			local compileResult = self._schemaRegistry:ValidateReady()
			if not compileResult.success then
				return fail(compileResult)
			end

			local finalizeResult = self:_FinalizeECSKernel()
			if not finalizeResult.success then
				return fail(finalizeResult)
			end

			local kernelReadyResult = self._lifecyclePolicy:ValidateKernelReady(self._schemaRegistry, self._systemRegistry)
			if kernelReadyResult ~= nil then
				return fail(kernelReadyResult)
			end

			local readyRuntimeResult = self._lifecycle:MarkReadyForRuntimeRegistration()
			if not readyRuntimeResult.success then
				return fail(readyRuntimeResult)
			end
			currentState = self._lifecycle:GetState()
		end

		if currentState == "ReadyForRuntimeRegistration" or currentState == "RegisteringRuntime" then
			local proofRuntimeResult = self:_EnsureBuiltInOperationalProofRuntime()
			if not proofRuntimeResult.success then
				return fail(proofRuntimeResult)
			end

			local finalizeRuntimeResult = self:_FinalizeRuntimeRegistrations()
			if not finalizeRuntimeResult.success then
				return fail(finalizeRuntimeResult)
			end

			local runtimeReadyResult = self._lifecyclePolicy:ValidateRuntimeBridgeReady(
				self._instanceBindingRegistry,
				self._syncContributorRegistry,
				self._replicationRegistry
			)
			if runtimeReadyResult ~= nil then
				return fail(runtimeReadyResult)
			end

			local readyAIResult = self._lifecycle:MarkReadyForAIRegistration()
			if not readyAIResult.success then
				return fail(readyAIResult)
			end
			currentState = self._lifecycle:GetState()
		end

		if currentState == "ReadyForAIRegistration" or currentState == "RegisteringAI" then
			local proofAIResult = self:_EnsureBuiltInOperationalProofActorType()
			if not proofAIResult.success then
				return fail(proofAIResult)
			end

			local finalizeAIResult = self._aiActorTypeRegistry:CloseRegistration()
			if not finalizeAIResult.success then
				return fail(finalizeAIResult)
			end

			local aiReadyResult = self._lifecyclePolicy:ValidateAIReady(self._aiActorTypeRegistry, self._combatAIRuntimeBridge)
			if aiReadyResult ~= nil then
				return fail(aiReadyResult)
			end

			local runningResult = self._lifecycle:StartRunning()
			if not runningResult.success then
				return fail(runningResult)
			end

			self._runtimeScheduler:BindSchedulerTick()
			self._startupState:ClearLastStartupFailure()
			return Result.Ok(true)
		end

		if currentState == "Running" then
			self._startupState:ClearLastStartupFailure()
			return Result.Ok(true)
		end

		return EntityOperationSupport.RequireLifecycleStates(self._validationService, "Start", currentState, {
			"RegisteringECS",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
		})
	end, self:_Label())
end

function StartCommand:_BeginECSCompile(): Result.Result<boolean>
	local transitionResult = self._lifecycle:BeginECSCompile()
	if not transitionResult.success then
		return transitionResult
	end

	return self._schemaRegistry:BeginCompile()
end

function StartCommand:_FinalizeECSKernel(): Result.Result<boolean>
	local closeSystemResult = self._systemRegistry:CloseRegistration()
	if not closeSystemResult.success then
		return closeSystemResult
	end

	return self._schemaRegistry:FinalizeCompile()
end

function StartCommand:_FinalizeRuntimeRegistrations(): Result.Result<boolean>
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

function StartCommand:_EnsureBuiltInOperationalProofRuntime(): Result.Result<boolean>
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

		local registerReplicationResult = self._replicationRegistry:RegisterReplicationSurface(EntityProofRuntimeConfig.FeatureName, replicationResult.value)
		if not registerReplicationResult.success then
			return registerReplicationResult
		end
	end

	local bindingEnableResult = self._runtimeParticipation:EnableFeature("Binding", EntityProofRuntimeConfig.FeatureName)
	if not bindingEnableResult.success then
		return bindingEnableResult
	end

	local replicationEnableResult = self._runtimeParticipation:EnableFeature("Replication", EntityProofRuntimeConfig.FeatureName)
	if not replicationEnableResult.success then
		return replicationEnableResult
	end

	return self._replicationService:EnableFeature(self._entityContext, EntityProofRuntimeConfig.FeatureName)
end

function StartCommand:_EnsureBuiltInOperationalProofActorType(): Result.Result<boolean>
	if self._aiActorTypeRegistry:GetCompiledActorType("Combat", EntityProofRuntimeConfig.ActorType) ~= nil then
		return Result.Ok(true)
	end

	local payload = {
		RuntimeKind = "Combat",
		ActorType = EntityProofRuntimeConfig.ActorType,
		Conditions = {},
		Commands = EntityProofRuntimeConfig.Commands,
		Executors = EntityProofRuntimeConfig.Executors,
		ResolveProfile = function(_entityContext: any, _entity: number)
			return {
				BehaviorDefinition = EntityProofRuntimeConfig.BehaviorDefinition,
				TickInterval = 0.1,
			}
		end,
		BuildActorHandle = function(_entityContext: any, entity: number)
			return string.format("%s:%d", EntityProofRuntimeConfig.ActorType, entity)
		end,
		IsEntityActive = function(entityContext: any, entity: number)
			local hasResult = entityContext:Has(entity, "ActiveTag")
			return hasResult.success and hasResult.value == true
		end,
		GetActorLabel = function(_entityContext: any, entity: number)
			return string.format("%s#%d", EntityProofRuntimeConfig.ActorType, entity)
		end,
		DependencyContract = {
			DependencyMode = "EntityContextOnly",
			AllowsRuntimeServices = true,
			DeclaredDependencies = { "EntityContext", "RuntimeServices" },
		},
	}

	local compiledResult = self._validationService:ValidateAIActorTypePayload(payload)
	if not compiledResult.success then
		return compiledResult
	end

	local registerResult = self._aiActorTypeRegistry:RegisterActorType(compiledResult.value)
	if not registerResult.success then
		return registerResult
	end

	local bridgeResult = self._combatAIRuntimeBridge:RegisterActorType(registerResult.value)
	if not bridgeResult.success then
		self._aiActorTypeRegistry:RemoveCompiledActorType(registerResult.value.RuntimeKind, registerResult.value.ActorType)
		return bridgeResult
	end

	if self._lifecycle:GetState() == "ReadyForAIRegistration" then
		return self._lifecycle:BeginAIRegistration()
	end

	return Result.Ok(true)
end

function StartCommand:_HandleStartupFailure()
	local currentState = self._lifecycle:GetState()
	self._runtimeScheduler:StopRuntimeTick()
	if currentState ~= "ShuttingDown" and currentState ~= "Destroyed" then
		self._lifecycle:BeginShutdown()
	end

	if self._lifecycle:GetState() == "ShuttingDown" then
		self._runtimeScheduler:StopRuntimeTick()
		EntityOperationSupport.ShutdownRuntimeExecution(self)
		EntityOperationSupport.FlushPendingDestructionDuringShutdown(self._entityFactory)
		self._lifecycle:MarkDestroyed()
	end
end

return StartCommand
