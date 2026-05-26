--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AI = require(game:GetService("ServerStorage").Utilities.ContextUtilities.AI)
local BaseExecutor = require(game:GetService("ServerStorage").Utilities.ContextUtilities.BaseExecutor)
local BaseApplication = require(game:GetService("ServerStorage").Utilities.ContextUtilities.BaseApplication.BaseApplication)
local Result = require(ReplicatedStorage.Utilities.Result)

local EntityPhases = require(ReplicatedStorage.Contexts.Entity.Config.EntityPhases)
local EntityCoreSchema = require(script.Parent.Parent.Parent.Infrastructure.ECS.Schemas.EntityCoreSchema)
local EntityProofSchema = require(script.Parent.Parent.Parent.Infrastructure.ECS.Schemas.EntityProofSchema)
local Errors = require(script.Parent.Parent.Parent.Errors)

local Catch = Result.Catch
local Ok = Result.Ok
local BehaviorSystem = AI.GetBehaviorSystem()

local PROOF_FEATURE_NAME = "EntityProof"
local PROOF_ARCHETYPE_NAME = "EntityProof.ProofActor"
local PROOF_ACTOR_TYPE = "EntityProof.Actor"
local PROOF_ACTION_ID = "EntityProof.Idle"
local PROOF_BEHAVIOR_DEFINITION = table.freeze({
	Sequence = {
		"EntityProofIdle",
	},
})

local ProofIdleExecutor = {}
ProofIdleExecutor.__index = ProofIdleExecutor
setmetatable(ProofIdleExecutor, BaseExecutor)

function ProofIdleExecutor.new()
	local self = BaseExecutor.new({
		ActionId = PROOF_ACTION_ID,
		IsCommitted = false,
	})
	return setmetatable(self, ProofIdleExecutor)
end

function ProofIdleExecutor:OnTick(_entity: number, _dt: number, _services: any): string
	return self:Running()
end

local PROOF_COMMANDS = table.freeze({
	EntityProofIdle = function()
		return BehaviorSystem.Helpers.CreateCommandTask(function(task, context)
			context.ActionFactory:SetPendingAction(context.Entity, PROOF_ACTION_ID, nil)
			task:success()
		end)
	end,
})

local PROOF_EXECUTORS = table.freeze({
	[PROOF_ACTION_ID] = table.freeze({
		ActionId = PROOF_ACTION_ID,
		CreateExecutor = ProofIdleExecutor.new,
	}),
})

local EntityKernelService = {}
EntityKernelService.__index = EntityKernelService
setmetatable(EntityKernelService, BaseApplication)

function EntityKernelService.new(baseContext: any, service: any)
	local self = BaseApplication.new("Entity", "EntityKernelService")
	self._baseContext = baseContext
	self._service = service
	self._schedulerTickBound = false
	self._lastStartupFailure = nil
	self._runtimeTickActive = false
	return setmetatable(self, EntityKernelService)
end

function EntityKernelService:Init(registry: any, _name: string)
	self:_RequireDependencies(registry, {
		_lifecycle = "EntityLifecycleStateMachine",
		_schemaRegistry = "EntitySchemaRegistry",
		_entityFactory = "EntityEntityFactory",
		_instanceBindingRegistry = "EntityInstanceBindingRegistry",
		_revealService = "EntityRevealService",
		_runtimeSnapshotBuilder = "EntityRuntimeSnapshotBuilder",
		_runtimeParticipation = "EntityRuntimeParticipationService",
		_instanceBindingService = "EntityInstanceBindingService",
		_runtimeSyncService = "EntityRuntimeSyncService",
		_syncContributorRegistry = "EntitySyncContributorRegistry",
		_replicationRegistry = "EntityReplicationRegistry",
		_replicationService = "EntityReplicationService",
		_aiActorTypeRegistry = "EntityAIActorTypeRegistry",
		_aiEntityRegistry = "EntityAIEntityRegistry",
		_combatAIRuntimeBridge = "EntityCombatAIRuntimeBridge",
		_systemRegistry = "EntitySystemRegistry",
		_validationService = "EntityValidationService",
		_aiActionStateService = "EntityAIActionStateService",
		_lifecyclePolicy = "EntityLifecyclePolicy",
		_readinessPolicy = "EntityReadinessPolicy",
	})
	self:_BindLifecycleHooks()
end

function EntityKernelService:Start(_registry: any, _name: string)
	return
end

function EntityKernelService:InitContext(_registry: any?, _name: string?): Result.Result<boolean>
	return Catch(function()
		local currentState = self._lifecycle:GetState()
		if currentState == "Uninitialized" then
			local transitionResult = self._lifecycle:BeginECSRegistration()
			if not transitionResult.success then
				return transitionResult
			end

			local builtInSchemaResult = self:_RegisterBuiltInSchemas()
			if not builtInSchemaResult.success then
				return builtInSchemaResult
			end

			return Ok(true)
		end

		if
			currentState == "RegisteringECS"
			or currentState == "CompilingECS"
			or currentState == "ReadyForRuntimeRegistration"
			or currentState == "RegisteringRuntime"
			or currentState == "ReadyForAIRegistration"
			or currentState == "RegisteringAI"
			or currentState == "Running"
		then
			return Ok(true)
		end

		return self:_RequireLifecycleStates("Init", {
			"Uninitialized",
			"RegisteringECS",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
		})
	end, "EntityKernelService:InitContext")
end

function EntityKernelService:StartContext(): Result.Result<boolean>
	return Catch(function()
		local function handleStartupFailure(failureResult: Result.Result<any>): Result.Result<any>
			self._lastStartupFailure = self:_BuildFailureSummary(failureResult)
			self:_HandleStartupFailure()
			return failureResult
		end

		local currentState = self._lifecycle:GetState()
		if currentState == "RegisteringECS" then
			local beginCompileResult = self:_BeginECSCompile()
			if not beginCompileResult.success then
				return handleStartupFailure(beginCompileResult)
			end
			currentState = self._lifecycle:GetState()
		end

		if currentState == "CompilingECS" then
			local compileResult = self:_CompileECSKernel()
			if not compileResult.success then
				return handleStartupFailure(compileResult)
			end

			local finalizeKernelResult = self:_FinalizeECSKernel()
			if not finalizeKernelResult.success then
				return handleStartupFailure(finalizeKernelResult)
			end

			local runtimeReadyResult = self._lifecycle:MarkReadyForRuntimeRegistration()
			if not runtimeReadyResult.success then
				return handleStartupFailure(runtimeReadyResult)
			end
			currentState = self._lifecycle:GetState()
		end

		if currentState == "ReadyForRuntimeRegistration" or currentState == "RegisteringRuntime" then
			local builtInRuntimeResult = self:_EnsureBuiltInOperationalProofRuntime()
			if not builtInRuntimeResult.success then
				return handleStartupFailure(builtInRuntimeResult)
			end

			local finalizeRuntimeResult = self:_FinalizeRuntimeRegistrations()
			if not finalizeRuntimeResult.success then
				return handleStartupFailure(finalizeRuntimeResult)
			end

			local readyResult = self._lifecycle:MarkReadyForAIRegistration()
			if not readyResult.success then
				return handleStartupFailure(readyResult)
			end
			currentState = self._lifecycle:GetState()
		end

		if currentState == "ReadyForAIRegistration" or currentState == "RegisteringAI" then
			local builtInAIResult = self:_EnsureBuiltInOperationalProofActorType()
			if not builtInAIResult.success then
				return handleStartupFailure(builtInAIResult)
			end

			local finalizeAIResult = self:_FinalizeAIRegistrations()
			if not finalizeAIResult.success then
				return handleStartupFailure(finalizeAIResult)
			end

			local runningResult = self._lifecycle:StartRunning()
			if not runningResult.success then
				return handleStartupFailure(runningResult)
			end

			return Ok(true)
		end

		if currentState == "Running" then
			self._lastStartupFailure = nil
			return Ok(true)
		end

		return self:_RequireLifecycleStates("Start", {
			"RegisteringECS",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
		})
	end, "EntityKernelService:StartContext")
end

function EntityKernelService:GetLifecycleState(): Result.Result<string>
	return Catch(function()
		return Ok(self._lifecycle:GetState())
	end, "EntityKernelService:GetLifecycleState")
end

function EntityKernelService:GetReadinessStatus(): Result.Result<any>
	return Catch(function()
		return Ok(self:_BuildReadinessStatus())
	end, "EntityKernelService:GetReadinessStatus")
end

function EntityKernelService:GetRegistrationStatus(): Result.Result<any>
	return Catch(function()
		return Ok(self:_BuildReadinessStatus())
	end, "EntityKernelService:GetRegistrationStatus")
end

function EntityKernelService:RunAcceptanceCheck(): Result.Result<any>
	return Catch(function()
		local readinessStatus = self:_BuildReadinessStatus()
		local acceptanceReport = table.clone(readinessStatus.Acceptance)
		acceptanceReport.LifecycleState = readinessStatus.LifecycleState
		return Ok(acceptanceReport)
	end, "EntityKernelService:RunAcceptanceCheck")
end

function EntityKernelService:RunOperationalProof(): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RunOperationalProof", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local proofResult = {
			Lifecycle = {
				InitPassed = true,
				StartPassed = self._lifecycle:GetState() == "Running",
				ShutdownPassed = false,
			},
			Runtime = {
				BindPassed = false,
				ReplicationBootstrapPassed = false,
				CleanupPassed = false,
			},
			AI = {
				ActorTypeRegistrationPassed = false,
				ActorEntityRegistrationPassed = false,
				UnregisterPassed = false,
			},
			Acceptance = {
				Passed = false,
				BlockingGaps = {},
			},
		}

		local proofEntity = nil
		local aiRegistered = false
		local runtimeRegistered = false
		local bindResult = Ok(nil)
		local registerRuntimeResult = Ok(false)
		local aiRegistrationResult = Ok("")

		local function finalizeAndReturn()
			local readinessStatus = self:_BuildReadinessStatus()
			local cleanupPassed = readinessStatus.Runtime.PendingBindCount == 0
				and readinessStatus.Runtime.BoundEntityCount == 0
				and readinessStatus.Runtime.RuntimeEntityCount == 0
				and readinessStatus.AI.RuntimeRegistrationCount == 0
			proofResult.Runtime.CleanupPassed = cleanupPassed
			proofResult.Lifecycle.ShutdownPassed = cleanupPassed
			if not cleanupPassed then
				table.insert(proofResult.Acceptance.BlockingGaps, {
					Code = "OperationalProofCleanupFailed",
					Message = Errors.OPERATIONAL_PROOF_FAILED,
					Details = readinessStatus,
				})
			end
			proofResult.Acceptance.Passed = cleanupPassed and #proofResult.Acceptance.BlockingGaps == 0
			proofResult.Acceptance.BlockingGaps = if #proofResult.Acceptance.BlockingGaps == 0
				then {}
				else proofResult.Acceptance.BlockingGaps

			return proofResult
		end

		local function cleanupProofState()
			if proofEntity == nil then
				return
			end

			if aiRegistered then
				self:UnregisterAIEntity(proofEntity)
				aiRegistered = false
				proofResult.AI.UnregisterPassed = true
			end

			if self._entityFactory:Exists(proofEntity) then
				self:DestroyEntity(proofEntity)
			elseif runtimeRegistered then
				self:UnregisterRuntimeEntity(proofEntity)
			end
			runtimeRegistered = false
			proofEntity = nil
		end

		local readinessStatus = self:_BuildReadinessStatus()
		proofResult.AI.ActorTypeRegistrationPassed = self._aiActorTypeRegistry:GetCompiledActorType("Combat", PROOF_ACTOR_TYPE)
				~= nil
			and readinessStatus.AI.StartupGateSatisfied
			and readinessStatus.AI.ActorTypesClosed
		if not proofResult.AI.ActorTypeRegistrationPassed then
			proofResult.Acceptance.BlockingGaps = {
				{
					Code = "OperationalProofActorTypeMissing",
					Message = Errors.MISSING_REQUIRED_AI_ACTOR_TYPE,
					Details = readinessStatus.AI,
				},
			}
			return Ok(finalizeAndReturn())
		end

		local createResult = self:CreateEntity(PROOF_ARCHETYPE_NAME, {
			Identity = {
				EntityId = "EntityProof.OperationalProof",
				EntityKind = PROOF_FEATURE_NAME,
				DefinitionId = "OperationalProof",
			},
			Health = {
				Current = 1,
				Max = 1,
			},
		})
		if not createResult.success then
			proofResult.Acceptance.BlockingGaps = {
				{
					Code = "OperationalProofCreateFailed",
					Message = createResult.message,
					Details = createResult.data,
				},
			}
			return Ok(finalizeAndReturn())
		end
		proofEntity = createResult.value

		bindResult = self:BindEntityInstance(proofEntity)
		proofResult.Runtime.BindPassed = bindResult.success and bindResult.value ~= nil

		registerRuntimeResult = self:RegisterRuntimeEntity(proofEntity)
		runtimeRegistered = registerRuntimeResult.success

		aiRegistrationResult = self:RegisterAIEntity(proofEntity, PROOF_ACTOR_TYPE)
		aiRegistered = aiRegistrationResult.success
		proofResult.AI.ActorEntityRegistrationPassed = aiRegistrationResult.success

		local primaryPlayer = Players:GetPlayers()[1]
		if primaryPlayer ~= nil then
			local hydrateResult = self:HydrateEntityReplication(primaryPlayer)
			local completeBootstrapResult = self:CompleteEntityReplicationBootstrap(primaryPlayer)
			proofResult.Runtime.ReplicationBootstrapPassed = hydrateResult.success and completeBootstrapResult.success
		else
			proofResult.Runtime.ReplicationBootstrapPassed = self._replicationService:GetStatus().BootCapable
		end

		cleanupProofState()

		if not proofResult.Runtime.BindPassed and bindResult.message ~= nil then
			table.insert(proofResult.Acceptance.BlockingGaps, {
				Code = "OperationalProofBindFailed",
				Message = bindResult.message,
				Details = bindResult.data,
			})
		end
		if not runtimeRegistered and registerRuntimeResult.message ~= nil then
			table.insert(proofResult.Acceptance.BlockingGaps, {
				Code = "OperationalProofRuntimeRegistrationFailed",
				Message = registerRuntimeResult.message,
				Details = registerRuntimeResult.data,
			})
		end
		if not proofResult.AI.ActorEntityRegistrationPassed and aiRegistrationResult.message ~= nil then
			table.insert(proofResult.Acceptance.BlockingGaps, {
				Code = "OperationalProofAIRegistrationFailed",
				Message = aiRegistrationResult.message,
				Details = aiRegistrationResult.data,
			})
		end
		if not proofResult.Runtime.ReplicationBootstrapPassed then
			table.insert(proofResult.Acceptance.BlockingGaps, {
				Code = "OperationalProofReplicationUnavailable",
				Message = Errors.OPERATIONAL_PROOF_FAILED,
				Details = {
					Reason = "ReplicationBootstrapUnavailable",
				},
			})
		end

		return Ok(finalizeAndReturn())
	end, "EntityKernelService:RunOperationalProof")
end

function EntityKernelService:RegisterFeatureSchema(featureName: string, schema: any): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterFeatureSchema", { "RegisteringECS" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._schemaRegistry:RegisterFeatureSchema(featureName, schema)
	end, "EntityKernelService:RegisterFeatureSchema")
end

function EntityKernelService:Get(entity: number, key: string, featureName: string?): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("Get", {
			"RegisteringECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Get(entity, key, featureName)
	end, "EntityKernelService:Get")
end

function EntityKernelService:Set(entity: number, key: string, value: any, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("Set", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Set(entity, key, value, featureName)
	end, "EntityKernelService:Set")
end

function EntityKernelService:Add(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("Add", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Add(entity, key, featureName)
	end, "EntityKernelService:Add")
end

function EntityKernelService:Remove(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("Remove", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Remove(entity, key, featureName)
	end, "EntityKernelService:Remove")
end

function EntityKernelService:Has(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("Has", {
			"RegisteringECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local getResult = self._entityFactory:Get(entity, key, featureName)
		if not getResult.success then
			local resolvedResult = self._schemaRegistry:ResolveAnyId(key, featureName)
			if resolvedResult.success and resolvedResult.value.Kind == "Tag" then
				return Result.Ok(false)
			end

			return getResult
		end

		local value = getResult.value
		if type(value) == "boolean" then
			return Result.Ok(value)
		end

		return Result.Ok(value ~= nil)
	end, "EntityKernelService:Has")
end

function EntityKernelService:Query(querySpec: any): Result.Result<{ number }>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("Query", {
			"RegisteringECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local queryValidationResult = self._validationService:ValidateQuerySpec(querySpec)
		if not queryValidationResult.success then
			return queryValidationResult
		end

		return self._entityFactory:Query(querySpec)
	end, "EntityKernelService:Query")
end

function EntityKernelService:RegisterSystem(phaseName: string, systemSpec: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterSystem", { "RegisteringECS" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RegisterSystem(phaseName, systemSpec)
	end, "EntityKernelService:RegisterSystem")
end

function EntityKernelService:TickPhase(phaseName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("TickPhase", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RunPhase(phaseName)
	end, "EntityKernelService:TickPhase")
end

function EntityKernelService:TickAll(): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("TickAll", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RunAllPhases()
	end, "EntityKernelService:TickAll")
end

function EntityKernelService:CreateEntity(archetypeName: string, payload: { [string]: any }?): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("CreateEntity", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:CreateFromArchetype(archetypeName, payload)
	end, "EntityKernelService:CreateEntity")
end

function EntityKernelService:DestroyEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("DestroyEntity", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local cleanupResult = self:_PrepareRuntimeEntityForRemoval(entity, true)
		if not cleanupResult.success then
			return cleanupResult
		end

		return self._entityFactory:DeleteEntityNow(entity)
	end, "EntityKernelService:DestroyEntity")
end

function EntityKernelService:MarkForDestruction(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("MarkForDestruction", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local cleanupResult = self:_PrepareRuntimeEntityForRemoval(entity, true)
		if not cleanupResult.success then
			return cleanupResult
		end

		return self._entityFactory:MarkEntityForDestruction(entity)
	end, "EntityKernelService:MarkForDestruction")
end

function EntityKernelService:FlushDestructionQueue(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushDestructionQueue", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:FlushDestroyQueue()
	end, "EntityKernelService:FlushDestructionQueue")
end

function EntityKernelService:EnableRuntimeBinding(featureName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("EnableRuntimeBinding", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if self._instanceBindingRegistry:GetBinding(featureName) == nil then
			return Result.Err("UnknownInstanceBinding", Errors.UNKNOWN_INSTANCE_BINDING, {
				FeatureName = featureName,
			})
		end

		return self._runtimeParticipation:EnableFeature("Binding", featureName)
	end, "EntityKernelService:EnableRuntimeBinding")
end

function EntityKernelService:EnableRuntimeSync(featureName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("EnableRuntimeSync", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
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
	end, "EntityKernelService:EnableRuntimeSync")
end

function EntityKernelService:EnableRuntimeReplication(featureName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("EnableRuntimeReplication", {
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

		return self._replicationService:EnableFeature(self, featureName)
	end, "EntityKernelService:EnableRuntimeReplication")
end

function EntityKernelService:RegisterRuntimeEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterRuntimeEntity", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local featureNameResult = self._runtimeParticipation:RegisterRuntimeEntity(entity)
		if not featureNameResult.success then
			return featureNameResult
		end

		if self._runtimeParticipation:IsFeatureEnabled("Binding", featureNameResult.value) then
			local queueResult = self._instanceBindingService:QueueEntityBind(entity)
			if not queueResult.success then
				self._runtimeParticipation:UnregisterRuntimeEntity(entity)
				return queueResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:RegisterRuntimeEntity")
end

function EntityKernelService:UnregisterRuntimeEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("UnregisterRuntimeEntity", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self:_PrepareRuntimeEntityForRemoval(entity, true)
	end, "EntityKernelService:UnregisterRuntimeEntity")
end

function EntityKernelService:GetWorld(): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetWorld", {
			"Uninitialized",
			"RegisteringECS",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._service._worldService:GetWorld())
	end, "EntityKernelService:GetWorld")
end

function EntityKernelService:GetFeatureComponents(featureName: string): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetFeatureComponents", {
			"Uninitialized",
			"RegisteringECS",
			"CompilingECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._schemaRegistry:GetFeatureComponents(featureName)
	end, "EntityKernelService:GetFeatureComponents")
end

function EntityKernelService:GetEntityFactory(): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetEntityFactory", {
			"Uninitialized",
			"RegisteringECS",
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._entityFactory)
	end, "EntityKernelService:GetEntityFactory")
end

function EntityKernelService:RegisterInstanceBinding(featureName: string, binding: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterInstanceBinding", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local validatedBindingResult = self._validationService:ValidateInstanceBinding(featureName, binding)
		if not validatedBindingResult.success then
			return validatedBindingResult
		end

		local registerResult = self._instanceBindingRegistry:RegisterBinding(featureName, validatedBindingResult.value)
		if not registerResult.success then
			return registerResult
		end

		if self._lifecycle:GetState() == "ReadyForRuntimeRegistration" then
			local transitionResult = self._lifecycle:BeginRuntimeRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:RegisterInstanceBinding")
end

function EntityKernelService:BindEntityInstance(entity: number): Result.Result<Instance?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("BindEntityInstance", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local runtimeParticipationResult = self:_RequireRuntimeBindingParticipation(entity)
		if not runtimeParticipationResult.success then
			return runtimeParticipationResult
		end

		local bindResult = self._instanceBindingService:BindEntityInstance(self, entity)
		if not bindResult.success then
			return bindResult
		end

		if bindResult.value ~= nil then
			local onBoundResult = self:_OnRuntimeEntityBound(entity)
			if not onBoundResult.success then
				return onBoundResult
			end
		end

		return bindResult
	end, "EntityKernelService:BindEntityInstance")
end

function EntityKernelService:UnbindEntityInstance(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("UnbindEntityInstance", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._instanceBindingService:UnbindEntityInstance(entity)
	end, "EntityKernelService:UnbindEntityInstance")
end

function EntityKernelService:QueueEntityBind(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("QueueEntityBind", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local runtimeParticipationResult = self:_RequireRuntimeBindingParticipation(entity)
		if not runtimeParticipationResult.success then
			return runtimeParticipationResult
		end

		return self._instanceBindingService:QueueEntityBind(entity)
	end, "EntityKernelService:QueueEntityBind")
end

function EntityKernelService:FlushBindQueue(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushBindQueue", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._instanceBindingService:FlushBindQueue(self, function(entity: number, _instance: Instance)
			self:_OnRuntimeEntityBound(entity)
		end)
	end, "EntityKernelService:FlushBindQueue")
end

function EntityKernelService:GetBoundInstance(entity: number): Result.Result<Instance?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetBoundInstance", {
			"Running",
			"ShuttingDown",
			"Destroyed",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._instanceBindingService:GetBoundInstance(entity))
	end, "EntityKernelService:GetBoundInstance")
end

function EntityKernelService:GetBoundEntity(instance: Instance): Result.Result<number?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetBoundEntity", {
			"Running",
			"ShuttingDown",
			"Destroyed",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._instanceBindingService:GetBoundEntity(instance))
	end, "EntityKernelService:GetBoundEntity")
end

function EntityKernelService:BuildRuntimeSnapshot(entity: number): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("BuildRuntimeSnapshot", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSnapshotBuilder:BuildSnapshot(entity)
	end, "EntityKernelService:BuildRuntimeSnapshot")
end

function EntityKernelService:RegisterSyncContributor(featureName: string, payload: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterSyncContributor", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local validatedContributorResult = self._validationService:ValidateSyncContributor(featureName, payload)
		if not validatedContributorResult.success then
			return validatedContributorResult
		end

		local contributorResult =
			self._syncContributorRegistry:RegisterSyncContributor(featureName, validatedContributorResult.value)
		if not contributorResult.success then
			return contributorResult
		end

		if self._lifecycle:GetState() == "ReadyForRuntimeRegistration" then
			local transitionResult = self._lifecycle:BeginRuntimeRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:RegisterSyncContributor")
end

function EntityKernelService:GetSyncContributor(featureName: string): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetSyncContributor", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._syncContributorRegistry:GetSyncContributor(featureName))
	end, "EntityKernelService:GetSyncContributor")
end

function EntityKernelService:RegisterReplicationSurface(featureName: string, payload: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterReplicationSurface", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local validatedSurfaceResult = self._validationService:ValidateReplicationSurface(featureName, payload)
		if not validatedSurfaceResult.success then
			return validatedSurfaceResult
		end

		local surfaceResult = self._replicationRegistry:RegisterReplicationSurface(featureName, validatedSurfaceResult.value)
		if not surfaceResult.success then
			return surfaceResult
		end

		if self._lifecycle:GetState() == "ReadyForRuntimeRegistration" then
			local transitionResult = self._lifecycle:BeginRuntimeRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:RegisterReplicationSurface")
end

function EntityKernelService:RunRuntimeSync(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RunRuntimeSync", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSyncService:RunRuntimeSync(self)
	end, "EntityKernelService:RunRuntimeSync")
end

function EntityKernelService:RunRuntimePoll(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RunRuntimePoll", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSyncService:RunRuntimePoll(self)
	end, "EntityKernelService:RunRuntimePoll")
end

function EntityKernelService:GetReplicationSurface(featureName: string): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetReplicationSurface", {
			"ReadyForRuntimeRegistration",
			"RegisteringRuntime",
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._replicationRegistry:GetReplicationSurface(featureName))
	end, "EntityKernelService:GetReplicationSurface")
end

function EntityKernelService:HydrateEntityReplication(player: Player): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("HydrateEntityReplication", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:HydratePlayerResult(player)
	end, "EntityKernelService:HydrateEntityReplication")
end

function EntityKernelService:CompleteEntityReplicationBootstrap(player: Player): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("CompleteEntityReplicationBootstrap", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:CompleteBootstrapResult(player)
	end, "EntityKernelService:CompleteEntityReplicationBootstrap")
end

function EntityKernelService:FlushEntityReplicationReliable(): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushEntityReplicationReliable", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushReliableResult()
	end, "EntityKernelService:FlushEntityReplicationReliable")
end

function EntityKernelService:FlushEntityReplicationUnreliable(): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult =
			self:_RequireLifecycleStates("FlushEntityReplicationUnreliable", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushUnreliableResult()
	end, "EntityKernelService:FlushEntityReplicationUnreliable")
end

function EntityKernelService:FlushEntityReplicationEntity(entity: number): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushEntityReplicationEntity", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushEntityResult(entity)
	end, "EntityKernelService:FlushEntityReplicationEntity")
end

function EntityKernelService:RegisterAIActorType(payload: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterAIActorType", {
			"ReadyForAIRegistration",
			"RegisteringAI",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local compiledActorTypeResult = self._validationService:ValidateAIActorTypePayload(payload)
		if not compiledActorTypeResult.success then
			return compiledActorTypeResult
		end

		local registerResult = self._aiActorTypeRegistry:RegisterActorType(compiledActorTypeResult.value)
		if not registerResult.success then
			return registerResult
		end

		local bridgeResult = self._combatAIRuntimeBridge:RegisterActorType(registerResult.value)
		if not bridgeResult.success then
			self._aiActorTypeRegistry:RemoveCompiledActorType(registerResult.value.RuntimeKind, registerResult.value.ActorType)
			return bridgeResult
		end

		if self._lifecycle:GetState() == "ReadyForAIRegistration" then
			local transitionResult = self._lifecycle:BeginAIRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:RegisterAIActorType")
end

function EntityKernelService:RegisterAIEntity(entity: number, actorType: string): Result.Result<string>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterAIEntity", { "RegisteringAI", "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local compiledActorType = self._aiActorTypeRegistry:GetCompiledActorType("Combat", actorType)
		if compiledActorType == nil then
			return Result.Err("UnknownAIActorType", Errors.UNKNOWN_AI_ACTOR_TYPE, {
				Entity = entity,
				ActorType = actorType,
				RuntimeKind = "Combat",
			})
		end

		if not self._entityFactory:Exists(entity) then
			return Result.Err("UnknownEntity", Errors.UNKNOWN_ENTITY, {
				Entity = entity,
			})
		end

		local registrationResult = self._combatAIRuntimeBridge:RegisterAIEntity(self, entity, compiledActorType)
		if not registrationResult.success then
			return registrationResult
		end

		local bridgeRegistration = registrationResult.value.Registration
		local profile = registrationResult.value.Profile
		local writeRuntimeResult =
			self:_WriteAIRegistrationRuntimeState(entity, compiledActorType, profile, bridgeRegistration.ActorHandle)
		if not writeRuntimeResult.success then
			self._combatAIRuntimeBridge:UnregisterAIEntity(bridgeRegistration.ActorHandle)
			self:_CleanupAIRegistration(bridgeRegistration, false)
			return writeRuntimeResult
		end

		local actionStateResult = self._combatAIRuntimeBridge:GetAIActionState(bridgeRegistration.ActorHandle)
		if actionStateResult.success and actionStateResult.value ~= nil then
			local writeActionStateResult =
				self:_WriteAIActionStateFromCombatState(entity, actionStateResult.value, os.clock())
			if not writeActionStateResult.success then
				self:_ClearAIRegistrationRuntimeState(entity)
				self._combatAIRuntimeBridge:UnregisterAIEntity(bridgeRegistration.ActorHandle)
				self:_CleanupAIRegistration(bridgeRegistration, false)
				return writeActionStateResult
			end
		else
			local defaultActionStateResult =
				self:_WriteAIActionState(entity, self._aiActionStateService:BuildDefault(os.clock()))
			if not defaultActionStateResult.success then
				self:_ClearAIRegistrationRuntimeState(entity)
				self._combatAIRuntimeBridge:UnregisterAIEntity(bridgeRegistration.ActorHandle)
				self:_CleanupAIRegistration(bridgeRegistration, false)
				return defaultActionStateResult
			end
		end

		local storeResult = self._aiEntityRegistry:RegisterAIRegistration(entity, bridgeRegistration)
		if not storeResult.success then
			self:_ClearAIRegistrationRuntimeState(entity)
			self._combatAIRuntimeBridge:UnregisterAIEntity(bridgeRegistration.ActorHandle)
			self:_CleanupAIRegistration(bridgeRegistration, false)
			return storeResult
		end

		return storeResult
	end, "EntityKernelService:RegisterAIEntity")
end

function EntityKernelService:UnregisterAIEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("UnregisterAIEntity", { "RegisteringAI", "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local registration = self._aiEntityRegistry:GetAIRegistration(entity)
		local actorHandleResult = self:_ReadAIActorHandle(entity)
		local actorHandle = if actorHandleResult.success then actorHandleResult.value else nil
		if registration == nil and actorHandle == nil then
			return Ok(false)
		end

		local unregisterResult = Ok(false)
		if actorHandle ~= nil then
			unregisterResult = self._combatAIRuntimeBridge:UnregisterAIEntity(actorHandle)
		end
		local clearResult = self:_ClearAIRegistrationRuntimeState(entity)
		if registration ~= nil then
			self:_CleanupAIRegistration(registration, true)
		end

		if not clearResult.success then
			return clearResult
		end
		if not unregisterResult.success then
			return unregisterResult
		end

		return Ok(true)
	end, "EntityKernelService:UnregisterAIEntity")
end

function EntityKernelService:GetAIActorHandle(entity: number): Result.Result<string?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetAIActorHandle", {
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local actorHandleResult = self:_ReadAIActorHandle(entity)
		if actorHandleResult.success and actorHandleResult.value ~= nil then
			return actorHandleResult
		end

		return Ok(self._aiEntityRegistry:GetAIActorHandle(entity))
	end, "EntityKernelService:GetAIActorHandle")
end

function EntityKernelService:GetAIRegistration(entity: number): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("GetAIRegistration", {
			"ReadyForAIRegistration",
			"RegisteringAI",
			"Running",
			"ShuttingDown",
		})
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local ecsStateResult = self:_ReadAIRegistrationRuntimeState(entity)
		local ecsState = if ecsStateResult.success then ecsStateResult.value else nil
		local transientState = self._aiEntityRegistry:GetAIRegistration(entity)
		if ecsState == nil and transientState == nil then
			return Ok(nil)
		end

		local merged = {
			Entity = entity,
			RuntimeKind = if ecsState ~= nil and ecsState.AIActorType ~= nil then ecsState.AIActorType.RuntimeKind else "Combat",
			ActorType = if ecsState ~= nil and ecsState.AIActorType ~= nil then ecsState.AIActorType.ActorType else nil,
			ActorHandle = if ecsState ~= nil and ecsState.AIRegistration ~= nil then ecsState.AIRegistration.ActorHandle else nil,
			RegisteredAt = if ecsState ~= nil and ecsState.AIRegistration ~= nil then ecsState.AIRegistration.RegisteredAt else nil,
			Profile = if ecsState ~= nil then ecsState.AIRuntimeProfile else nil,
			BehaviorConfig = if ecsState ~= nil then ecsState.AIBehaviorConfig else nil,
			ActionState = if ecsState ~= nil then ecsState.AIActionState else nil,
			CompiledActorType = if transientState ~= nil then transientState.CompiledActorType else nil,
			FactsResolver = if transientState ~= nil then transientState.FactsResolver else nil,
			ServicesResolver = if transientState ~= nil then transientState.ServicesResolver else nil,
			IsCleanedUp = if transientState ~= nil then transientState.IsCleanedUp else nil,
		}

		return Ok(merged)
	end, "EntityKernelService:GetAIRegistration")
end

function EntityKernelService:DestroyContext(): Result.Result<boolean>
	return Catch(function()
		local currentState = self._lifecycle:GetState()

		if currentState ~= "Destroyed" then
			self._runtimeTickActive = false
			if
				currentState == "RegisteringECS"
				or currentState == "CompilingECS"
				or currentState == "ReadyForRuntimeRegistration"
				or currentState == "RegisteringRuntime"
				or currentState == "ReadyForAIRegistration"
				or currentState == "RegisteringAI"
				or currentState == "Running"
			then
				local shutdownResult = self._lifecycle:BeginShutdown()
				if not shutdownResult.success then
					return shutdownResult
				end
			elseif currentState ~= "ShuttingDown" then
				return self:_RequireLifecycleStates("Destroy", {
					"RegisteringECS",
					"CompilingECS",
					"ReadyForRuntimeRegistration",
					"RegisteringRuntime",
					"ReadyForAIRegistration",
					"RegisteringAI",
					"Running",
					"ShuttingDown",
					"Destroyed",
				})
			end

			if self._lifecycle:GetState() == "ShuttingDown" then
				local destroyedResult = self._lifecycle:MarkDestroyed()
				if not destroyedResult.success then
					return destroyedResult
				end
			end
		end

		self._lifecycle:Destroy()

		local destroyResult = self._baseContext:Destroy()
		if not destroyResult.success then
			return destroyResult
		end

		return Ok(true)
	end, "EntityKernelService:DestroyContext")
end

function EntityKernelService:GetRuntimeExecutionStatus(): any
	return {
		SchedulerBound = self._schedulerTickBound,
		RuntimeTickActive = self._runtimeTickActive,
		LastStartupFailure = self._lastStartupFailure,
	}
end

function EntityKernelService:_BindLifecycleHooks()
	self._lifecycle:RegisterTransitionGuard("CompilingECS", "ReadyForRuntimeRegistration", function()
		return self:_ValidateKernelReadyForStart()
	end)
	self._lifecycle:RegisterTransitionGuard("ReadyForRuntimeRegistration", "ReadyForAIRegistration", function()
		return self:_ValidateRuntimeBridgeReadyForAIRegistration()
	end)
	self._lifecycle:RegisterTransitionGuard("RegisteringRuntime", "ReadyForAIRegistration", function()
		return self:_ValidateRuntimeBridgeReadyForAIRegistration()
	end)
	self._lifecycle:RegisterTransitionGuard("ReadyForAIRegistration", "Running", function()
		return self:_ValidateAIRegistrationReadyForRun()
	end)
	self._lifecycle:RegisterTransitionGuard("RegisteringAI", "Running", function()
		return self:_ValidateAIRegistrationReadyForRun()
	end)
	self._lifecycle:RegisterOnEnter("Running", function()
		self._runtimeTickActive = true
		self._lastStartupFailure = nil
		self:_BindSchedulerTick()
	end)
	self._lifecycle:RegisterOnEnter("ShuttingDown", function()
		self._runtimeTickActive = false
		self:_ShutdownRuntimeExecution()
		self:_FlushPendingDestructionDuringShutdown()
	end)
	self._lifecycle:RegisterOnEnter("Destroyed", function()
		self._runtimeTickActive = false
	end)
end

function EntityKernelService:_RegisterBuiltInSchemas(): Result.Result<boolean>
	if self._schemaRegistry:HasFeature(EntityCoreSchema.FeatureName) then
		if self._schemaRegistry:HasFeature(EntityProofSchema.FeatureName) then
			return Ok(true)
		end
	else
		local registerResult = self._schemaRegistry:RegisterCoreSchema(EntityCoreSchema)
		if not registerResult.success then
			return registerResult
		end
	end

	if not self._schemaRegistry:HasFeature(EntityProofSchema.FeatureName) then
		local registerProofResult = self._schemaRegistry:RegisterFeatureSchema(EntityProofSchema.FeatureName, EntityProofSchema)
		if not registerProofResult.success then
			return registerProofResult
		end
	end

	return Ok(true)
end

function EntityKernelService:_EnsureBuiltInOperationalProofRuntime(): Result.Result<boolean>
	return Catch(function()
		if self._instanceBindingRegistry:GetBinding(PROOF_FEATURE_NAME) == nil then
			local registerBindingResult = self:RegisterInstanceBinding(PROOF_FEATURE_NAME, {
				FeatureName = PROOF_FEATURE_NAME,
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
			if not registerBindingResult.success then
				return registerBindingResult
			end
		end

		if self._syncContributorRegistry:GetSyncContributor(PROOF_FEATURE_NAME) == nil then
			local registerSyncContributorResult = self:RegisterSyncContributor(PROOF_FEATURE_NAME, {
				FeatureName = PROOF_FEATURE_NAME,
				QuerySyncEntities = function(_entityContext: any)
					return {}
				end,
				QueryPollEntities = function(_entityContext: any)
					return {}
				end,
			})
			if not registerSyncContributorResult.success then
				return registerSyncContributorResult
			end
		end

		if self._replicationRegistry:GetReplicationSurface(PROOF_FEATURE_NAME) == nil then
			local registerReplicationResult = self:RegisterReplicationSurface(PROOF_FEATURE_NAME, {
				FeatureName = PROOF_FEATURE_NAME,
				BuildSchema = function(_entityContext: any)
					return {
						sharedComponents = {},
						sharedTags = {},
					}
				end,
			})
			if not registerReplicationResult.success then
				return registerReplicationResult
			end
		end

		local bindingEnableResult = self:EnableRuntimeBinding(PROOF_FEATURE_NAME)
		if not bindingEnableResult.success then
			return bindingEnableResult
		end

		local replicationEnableResult = self:EnableRuntimeReplication(PROOF_FEATURE_NAME)
		if not replicationEnableResult.success then
			return replicationEnableResult
		end

		return Ok(true)
	end, "EntityKernelService:_EnsureBuiltInOperationalProofRuntime")
end

function EntityKernelService:_EnsureBuiltInOperationalProofActorType(): Result.Result<boolean>
	return Catch(function()
		if self._aiActorTypeRegistry:GetCompiledActorType("Combat", PROOF_ACTOR_TYPE) ~= nil then
			return Ok(true)
		end

		return self:RegisterAIActorType({
			RuntimeKind = "Combat",
			ActorType = PROOF_ACTOR_TYPE,
			Conditions = {},
			Commands = PROOF_COMMANDS,
			Executors = PROOF_EXECUTORS,
			ResolveProfile = function(_entityContext: any, _entity: number)
				return {
					BehaviorDefinition = PROOF_BEHAVIOR_DEFINITION,
					TickInterval = 0.1,
				}
			end,
			BuildActorHandle = function(_entityContext: any, entity: number)
				return string.format("%s:%d", PROOF_ACTOR_TYPE, entity)
			end,
			IsEntityActive = function(entityContext: any, entity: number)
				local hasResult = entityContext:Has(entity, "ActiveTag")
				return hasResult.success and hasResult.value == true
			end,
			GetActorLabel = function(_entityContext: any, entity: number)
				return string.format("%s#%d", PROOF_ACTOR_TYPE, entity)
			end,
			DependencyContract = {
				DependencyMode = "EntityContextOnly",
				AllowsRuntimeServices = true,
				DeclaredDependencies = { "EntityContext", "RuntimeServices" },
			},
		})
	end, "EntityKernelService:_EnsureBuiltInOperationalProofActorType")
end

function EntityKernelService:_BeginECSCompile(): Result.Result<boolean>
	return Catch(function()
		local transitionResult = self._lifecycle:BeginECSCompile()
		if not transitionResult.success then
			return transitionResult
		end

		return self._schemaRegistry:BeginCompile()
	end, "EntityKernelService:_BeginECSCompile")
end

function EntityKernelService:_CompileECSKernel(): Result.Result<boolean>
	return Catch(function()
		return self._schemaRegistry:ValidateReady()
	end, "EntityKernelService:_CompileECSKernel")
end

function EntityKernelService:_FinalizeECSKernel(): Result.Result<boolean>
	return Catch(function()
		local closeSystemResult = self._systemRegistry:CloseRegistration()
		if not closeSystemResult.success then
			return closeSystemResult
		end

		return self._schemaRegistry:FinalizeCompile()
	end, "EntityKernelService:_FinalizeECSKernel")
end

function EntityKernelService:_FinalizeRuntimeRegistrations(): Result.Result<boolean>
	return Catch(function()
		local closeBindingResult = self._instanceBindingRegistry:CloseRegistration()
		if not closeBindingResult.success then
			return closeBindingResult
		end

		local closeSyncResult = self._syncContributorRegistry:CloseRegistration()
		if not closeSyncResult.success then
			return closeSyncResult
		end

		return self._replicationRegistry:CloseRegistration()
	end, "EntityKernelService:_FinalizeRuntimeRegistrations")
end

function EntityKernelService:_FinalizeAIRegistrations(): Result.Result<boolean>
	return Catch(function()
		return self._aiActorTypeRegistry:CloseRegistration()
	end, "EntityKernelService:_FinalizeAIRegistrations")
end

function EntityKernelService:_BindSchedulerTick()
	if self._schedulerTickBound then
		return
	end

	self._schedulerTickBound = true
	self._baseContext:RegisterSchedulerSystem(EntityPhases.SchedulerPhase, function()
		self:_RunScheduledTick()
	end)
end

function EntityKernelService:_RunScheduledTick()
	if self._lifecycle:GetState() ~= "Running" then
		self._runtimeTickActive = false
		return
	end

	self._runtimeTickActive = true

	local bindResult = self:FlushBindQueue()
	if not bindResult.success then
		Result.MentionError("EntityKernelService:RunScheduledTick", "Entity bind queue flush failed", {
			CauseType = bindResult.type,
			CauseMessage = bindResult.message,
			Details = bindResult.data,
		}, bindResult.type)
	end

	local runResult = self._systemRegistry:RunAllPhases()
	if not runResult.success then
		Result.MentionError("EntityKernelService:RunScheduledTick", "Entity system tick failed", {
			CauseType = runResult.type,
			CauseMessage = runResult.message,
			Details = runResult.data,
		}, runResult.type)
	end

	local syncResult = self:RunRuntimeSync()
	if not syncResult.success then
		Result.MentionError("EntityKernelService:RunScheduledTick", "Entity runtime sync failed", {
			CauseType = syncResult.type,
			CauseMessage = syncResult.message,
			Details = syncResult.data,
		}, syncResult.type)
	end

	local pollResult = self:RunRuntimePoll()
	if not pollResult.success then
		Result.MentionError("EntityKernelService:RunScheduledTick", "Entity runtime poll failed", {
			CauseType = pollResult.type,
			CauseMessage = pollResult.message,
			Details = pollResult.data,
		}, pollResult.type)
	end

	local reliableResult = self:FlushEntityReplicationReliable()
	if not reliableResult.success then
		Result.MentionError("EntityKernelService:RunScheduledTick", "Entity reliable replication flush failed", {
			CauseType = reliableResult.type,
			CauseMessage = reliableResult.message,
			Details = reliableResult.data,
		}, reliableResult.type)
	end

	local unreliableResult = self:FlushEntityReplicationUnreliable()
	if not unreliableResult.success then
		Result.MentionError("EntityKernelService:RunScheduledTick", "Entity unreliable replication flush failed", {
			CauseType = unreliableResult.type,
			CauseMessage = unreliableResult.message,
			Details = unreliableResult.data,
		}, unreliableResult.type)
	end
end

function EntityKernelService:_FlushPendingDestructionDuringShutdown()
	local flushResult = self._entityFactory:FlushDestroyQueue()
	if not flushResult.success then
		Result.MentionError("EntityKernelService:Shutdown", "Failed to flush destruction queue during shutdown", {
			CauseType = flushResult.type,
			CauseMessage = flushResult.message,
			Details = flushResult.data,
		}, flushResult.type)
	end
end

function EntityKernelService:_ValidateKernelReadyForStart(): Result.Err?
	return self._lifecyclePolicy:ValidateKernelReady(self._schemaRegistry, self._systemRegistry)
end

function EntityKernelService:_ValidateRuntimeBridgeReadyForAIRegistration(): Result.Err?
	return self._lifecyclePolicy:ValidateRuntimeBridgeReady(
		self._instanceBindingRegistry,
		self._syncContributorRegistry,
		self._replicationRegistry
	)
end

function EntityKernelService:_ValidateAIRegistrationReadyForRun(): Result.Err?
	return self._lifecyclePolicy:ValidateAIReady(self._aiActorTypeRegistry, self._combatAIRuntimeBridge)
end

function EntityKernelService:_HandleStartupFailure()
	local currentState = self._lifecycle:GetState()
	self._runtimeTickActive = false
	if currentState ~= "ShuttingDown" and currentState ~= "Destroyed" then
		self._lifecycle:BeginShutdown()
	end

	if self._lifecycle:GetState() == "ShuttingDown" then
		self:_ShutdownRuntimeExecution()
		self:_FlushPendingDestructionDuringShutdown()
		self._lifecycle:MarkDestroyed()
	end
end

function EntityKernelService:_RequireRuntimeBindingParticipation(entity: number): Result.Result<boolean>
	local featureName = self._runtimeParticipation:GetFeatureName(entity)
	if featureName == nil then
		return Result.Err("UnknownRuntimeEntity", Errors.UNKNOWN_RUNTIME_ENTITY, {
			Entity = entity,
		})
	end

	if not self._runtimeParticipation:IsFeatureEnabled("Binding", featureName) then
		return Result.Err("FeatureRuntimeNotEnabled", Errors.FEATURE_RUNTIME_NOT_ENABLED, {
			Entity = entity,
			FeatureName = featureName,
			Mode = "Binding",
		})
	end

	return Ok(true)
end

function EntityKernelService:_OnRuntimeEntityBound(entity: number): Result.Result<boolean>
	return Catch(function()
		local featureName = self._runtimeParticipation:GetFeatureName(entity)
		if featureName == nil then
			return Ok(false)
		end

		if self._runtimeParticipation:IsFeatureEnabled("Replication", featureName) then
			local replicationResult = self._replicationService:RegisterRuntimeEntity(self, entity)
			if not replicationResult.success then
				return replicationResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:_OnRuntimeEntityBound")
end

function EntityKernelService:_PrepareRuntimeEntityForRemoval(entity: number, unregisterRuntimeEntity: boolean): Result.Result<boolean>
	return Catch(function()
		self._instanceBindingService:ClearQueuedBind(entity)

		local runtimeFeatureName = self._runtimeParticipation:GetFeatureName(entity)
		if runtimeFeatureName ~= nil and self._runtimeParticipation:IsFeatureEnabled("Replication", runtimeFeatureName) then
			local unregisterReplicationResult = self._replicationService:UnregisterRuntimeEntity(self, entity)
			if not unregisterReplicationResult.success then
				return unregisterReplicationResult
			end
		end

		local unbindResult = self._instanceBindingService:UnbindEntityInstance(entity)
		if not unbindResult.success then
			return unbindResult
		end

		local aiRegistration = self._aiEntityRegistry:GetAIRegistration(entity)
		if aiRegistration ~= nil then
			local unregisterAIResult = self:UnregisterAIEntity(entity)
			if not unregisterAIResult.success then
				return unregisterAIResult
			end
		end

		if unregisterRuntimeEntity then
			local unregisterRuntimeResult = self._runtimeParticipation:UnregisterRuntimeEntity(entity)
			if not unregisterRuntimeResult.success then
				return unregisterRuntimeResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:_PrepareRuntimeEntityForRemoval")
end

function EntityKernelService:_ShutdownRuntimeExecution()
	for _, entity in ipairs(self._aiEntityRegistry:CollectRegisteredEntities()) do
		self:UnregisterAIEntity(entity)
	end

	for _, entity in ipairs(self._runtimeParticipation:CollectRuntimeEntities()) do
		self:_PrepareRuntimeEntityForRemoval(entity, true)
	end

	self._instanceBindingService:DestroyAll()
end

function EntityKernelService:_BuildCombatAIActorAdapter(registration: any): any
	return {
		IsActive = function(): boolean
			return self:_IsAIRegistrationActive(registration)
		end,
		GetActorLabel = function(): string?
			return self:_GetAIRegistrationActorLabel(registration)
		end,
		BuildFacts = function(currentTime: number): { [string]: any }
			return self:_BuildAIRegistrationFacts(registration, currentTime)
		end,
		BuildServices = function(currentTime: number, tickId: number?, frameContext: any?): { [string]: any }
			return self:_BuildAIRegistrationServices(registration, currentTime, tickId, frameContext)
		end,
		OnCancel = function()
			self:_RunAIRegistrationCallback(registration, "OnCancel")
		end,
		OnRemoved = function()
			self:_ClearAIRegistrationRuntimeState(registration.Entity)
			self:_CleanupAIRegistration(registration, true)
			self:_RunAIRegistrationCallback(registration, "OnRemoved")
		end,
		OnActionResult = function(actionResult: any)
			self:_RunAIRegistrationCallback(registration, "OnActionResult", actionResult)
		end,
		OnActionStateChanged = function(actionState: any)
			self:_WriteAIActionStateFromCombatState(registration.Entity, actionState, os.clock())
			self:_RunAIRegistrationCallback(registration, "OnActionStateChanged", actionState)
		end,
	}
end

function EntityKernelService:_IsAIRegistrationActive(registration: any): boolean
	local didCheck, isActive = pcall(registration.CompiledActorType.IsEntityActive, self, registration.Entity)
	if not didCheck then
		Result.MentionError("EntityKernelService:AI", "AI active callback failed", {
			ActorType = registration.CompiledActorType.ActorType,
			ActorHandle = registration.ActorHandle,
			Entity = registration.Entity,
			RuntimeKind = registration.RuntimeKind,
			Stage = "IsActive",
			CauseMessage = isActive,
		}, "EntityAIActiveCallbackFailed")
		return false
	end

	return isActive == true
end

function EntityKernelService:_GetAIRegistrationActorLabel(registration: any): string?
	local getActorLabel = registration.CompiledActorType.GetActorLabel
	if type(getActorLabel) ~= "function" then
		return nil
	end

	local didResolve, actorLabel = pcall(getActorLabel, self, registration.Entity)
	if not didResolve or (actorLabel ~= nil and type(actorLabel) ~= "string") then
		return nil
	end

	return actorLabel
end

function EntityKernelService:_BuildAIRegistrationFacts(registration: any, currentTime: number): { [string]: any }
	local factsResolver = registration.FactsResolver
	local buildFacts = if type(factsResolver) == "table" then factsResolver.BuildFacts else factsResolver
	if type(buildFacts) ~= "function" then
		return {}
	end

	local didBuild, facts
	if type(factsResolver) == "table" then
		didBuild, facts = pcall(buildFacts, factsResolver, registration.Entity, currentTime)
	else
		didBuild, facts = pcall(buildFacts, registration.Entity, currentTime)
	end

	if not didBuild or type(facts) ~= "table" then
		Result.MentionError("EntityKernelService:AI", "AI facts resolver failed", {
			ActorType = registration.CompiledActorType.ActorType,
			ActorHandle = registration.ActorHandle,
			Entity = registration.Entity,
			RuntimeKind = registration.RuntimeKind,
			Stage = "BuildFacts",
			CauseMessage = facts,
		}, "EntityAIFactsResolverFailed")
		return {}
	end

	return facts
end

function EntityKernelService:_BuildAIRegistrationServices(
	registration: any,
	currentTime: number,
	tickId: number?,
	frameContext: any?
): { [string]: any }
	local servicesResolver = registration.ServicesResolver
	local buildServices = if type(servicesResolver) == "table" then servicesResolver.BuildServices else servicesResolver
	if type(buildServices) ~= "function" then
		return {}
	end

	local didBuild, services
	if type(servicesResolver) == "table" then
		didBuild, services = pcall(buildServices, servicesResolver, registration.Entity, currentTime, tickId, frameContext)
	else
		didBuild, services = pcall(buildServices, registration.Entity, currentTime, tickId, frameContext)
	end

	if not didBuild or type(services) ~= "table" then
		Result.MentionError("EntityKernelService:AI", "AI services resolver failed", {
			ActorType = registration.CompiledActorType.ActorType,
			ActorHandle = registration.ActorHandle,
			Entity = registration.Entity,
			RuntimeKind = registration.RuntimeKind,
			Stage = "BuildServices",
			CauseMessage = services,
		}, "EntityAIServicesResolverFailed")
		return {}
	end

	return services
end

function EntityKernelService:_RunAIRegistrationCallback(registration: any, callbackName: string, callbackArgument: any?)
	local callback = registration.CompiledActorType[callbackName]
	if type(callback) ~= "function" then
		return
	end

	local didRun, callbackError
	if callbackArgument == nil then
		didRun, callbackError = pcall(callback, self, registration.Entity)
	else
		didRun, callbackError = pcall(callback, self, registration.Entity, callbackArgument)
	end

	if didRun then
		return
	end

	Result.MentionError("EntityKernelService:AI", "AI registration callback failed", {
		ActorType = registration.CompiledActorType.ActorType,
		ActorHandle = registration.ActorHandle,
		Entity = registration.Entity,
		RuntimeKind = registration.RuntimeKind,
		Stage = callbackName,
		CauseMessage = callbackError,
	}, "EntityAIRegistrationCallbackFailed")
end

function EntityKernelService:_CleanupAIRegistration(registration: any, removeRegistration: boolean)
	if not registration.IsCleanedUp then
		local servicesResolver = registration.ServicesResolver
		if type(servicesResolver) == "table" then
			if type(servicesResolver.Cleanup) == "function" then
				pcall(servicesResolver.Cleanup, servicesResolver, registration.Entity)
			end
			if type(servicesResolver.Invalidate) == "function" then
				pcall(servicesResolver.Invalidate, servicesResolver, registration.Entity)
			end
		end

		local factsResolver = registration.FactsResolver
		if type(factsResolver) == "table" then
			if type(factsResolver.Cleanup) == "function" then
				pcall(factsResolver.Cleanup, factsResolver, registration.Entity)
			end
			if type(factsResolver.Invalidate) == "function" then
				pcall(factsResolver.Invalidate, factsResolver, registration.Entity)
			end
		end

		registration.IsCleanedUp = true
	end

	if removeRegistration then
		self._aiEntityRegistry:RemoveAIRegistration(registration.Entity)
	end
end

function EntityKernelService:_WriteAIRegistrationRuntimeState(
	entity: number,
	compiledActorType: any,
	profile: any,
	actorHandle: string
): Result.Result<boolean>
	return Catch(function()
		local registeredAt = os.clock()
		local actorTypeResult = self._entityFactory:Set(entity, "AIActorType", {
			RuntimeKind = compiledActorType.RuntimeKind,
			ActorType = compiledActorType.ActorType,
		})
		if not actorTypeResult.success then
			return actorTypeResult
		end

		local runtimeProfileResult = self._entityFactory:Set(entity, "AIRuntimeProfile", {
			RuntimeProfileId = actorHandle,
			TickInterval = profile.TickInterval,
		})
		if not runtimeProfileResult.success then
			return runtimeProfileResult
		end

		local behaviorConfigResult = self._entityFactory:Set(entity, "AIBehaviorConfig", {
			BehaviorDefinition = profile.BehaviorDefinition,
			TickInterval = profile.TickInterval,
		})
		if not behaviorConfigResult.success then
			return behaviorConfigResult
		end

		local registrationResult = self._entityFactory:Set(entity, "AIRegistration", {
			ActorHandle = actorHandle,
			RegisteredAt = registeredAt,
		})
		if not registrationResult.success then
			return registrationResult
		end

		return Ok(true)
	end, "EntityKernelService:_WriteAIRegistrationRuntimeState")
end

function EntityKernelService:_WriteAIActionState(entity: number, actionState: any): Result.Result<boolean>
	return self._entityFactory:Set(entity, "AIActionState", actionState)
end

function EntityKernelService:_WriteAIActionStateFromCombatState(
	entity: number,
	combatActionState: any,
	timestamp: number
): Result.Result<boolean>
	return self:_WriteAIActionState(entity, self._aiActionStateService:MapFromCombatState(combatActionState, timestamp))
end

function EntityKernelService:_ClearAIRegistrationRuntimeState(entity: number): Result.Result<boolean>
	return Catch(function()
		local componentKeys = { "AIActionState", "AIRegistration", "AIBehaviorConfig", "AIRuntimeProfile", "AIActorType" }
		for _, componentKey in ipairs(componentKeys) do
			local removeResult = self._entityFactory:Remove(entity, componentKey)
			if not removeResult.success then
				return removeResult
			end
		end

		return Ok(true)
	end, "EntityKernelService:_ClearAIRegistrationRuntimeState")
end

function EntityKernelService:_ReadAIActorHandle(entity: number): Result.Result<string?>
	return Catch(function()
		local registrationResult = self._entityFactory:Get(entity, "AIRegistration")
		if not registrationResult.success or type(registrationResult.value) ~= "table" then
			return Ok(nil)
		end

		local actorHandle = registrationResult.value.ActorHandle
		if type(actorHandle) ~= "string" or actorHandle == "" then
			return Ok(nil)
		end

		return Ok(actorHandle)
	end, "EntityKernelService:_ReadAIActorHandle")
end

function EntityKernelService:_ReadAIRegistrationRuntimeState(entity: number): Result.Result<any?>
	return Catch(function()
		if not self._entityFactory:Exists(entity) then
			return Ok(nil)
		end

		local keys = { "AIActorType", "AIRuntimeProfile", "AIActionState", "AIBehaviorConfig", "AIRegistration" }
		local state = {}
		local hasAnyState = false
		for _, componentKey in ipairs(keys) do
			local readResult = self._entityFactory:Get(entity, componentKey)
			if not readResult.success then
				continue
			end
			if readResult.value ~= nil then
				hasAnyState = true
			end
			state[componentKey] = readResult.value
		end

		if not hasAnyState then
			return Ok(nil)
		end

		return Ok(state)
	end, "EntityKernelService:_ReadAIRegistrationRuntimeState")
end

function EntityKernelService:_RequireLifecycleStates(methodName: string, expectedStates: { string }): Result.Result<boolean>
	return self._lifecyclePolicy:RequireStates(
		self._validationService,
		methodName,
		self._lifecycle:GetState(),
		expectedStates
	)
end

function EntityKernelService:_BuildReadinessStatus(): any
	return self._readinessPolicy:BuildStatus({
		LifecycleState = self._lifecycle:GetState(),
		SchemaStatus = self._schemaRegistry:GetStatus(),
		SystemStatus = self._systemRegistry:GetStatus(),
		InstanceBindingRegistryStatus = self._instanceBindingRegistry:GetStatus(),
		SyncContributorRegistryStatus = self._syncContributorRegistry:GetStatus(),
		ReplicationRegistryStatus = self._replicationRegistry:GetStatus(),
		AIActorTypeRegistryStatus = self._aiActorTypeRegistry:GetStatus(),
		AIBridgeStatus = self._combatAIRuntimeBridge:GetStatus(),
		ReplicationServiceStatus = self._replicationService:GetStatus(),
		InstanceBindingServiceStatus = self._instanceBindingService:GetStatus(),
		RuntimeParticipationStatus = self._runtimeParticipation:GetStatus(),
		AIEntityRegistryStatus = self._aiEntityRegistry:GetStatus(),
		SchemaReady = self._schemaRegistry:ValidateReady().success,
		SystemReady = self._systemRegistry:ValidateReady().success,
		RuntimeBindingsReady = self._instanceBindingRegistry:ValidateReady().success,
		RuntimeSyncReady = self._syncContributorRegistry:ValidateReady().success,
		RuntimeReplicationReady = self._replicationRegistry:ValidateReady().success,
		AIActorTypesReady = self._aiActorTypeRegistry:ValidateReady().success,
		AIBridgeReady = self._combatAIRuntimeBridge:ValidateReady().success,
		SchedulerBound = self._schedulerTickBound,
		RuntimeTickActive = self._runtimeTickActive,
		LastStartupFailure = self._lastStartupFailure,
	})
end

function EntityKernelService:_BuildFailureSummary(failureResult: Result.Result<any>): any
	if failureResult == nil then
		return nil
	end

	return {
		Type = failureResult.type,
		Message = failureResult.message,
		Data = failureResult.data,
	}
end

return EntityKernelService
