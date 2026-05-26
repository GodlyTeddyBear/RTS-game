--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local AI = require(ServerStorage.Utilities.ContextUtilities.AI)
local BaseExecutor = require(ServerStorage.Utilities.ContextUtilities.BaseExecutor)
local Result = require(ReplicatedStorage.Utilities.Result)

local EntityPhases = require(ReplicatedStorage.Contexts.Entity.Config.EntityPhases)
local Errors = require(script.Parent.Errors)
local EntityAIActorTypeRegistry = require(script.Parent.Infrastructure.AI.EntityAIActorTypeRegistry)
local EntityAIEntityRegistry = require(script.Parent.Infrastructure.AI.EntityAIEntityRegistry)
local EntityCombatAIRuntimeBridge = require(script.Parent.Infrastructure.AI.EntityCombatAIRuntimeBridge)
local EntityECSWorldService = require(script.Parent.Infrastructure.ECS.EntityECSWorldService)
local EntitySchemaRegistry = require(script.Parent.Infrastructure.ECS.EntitySchemaRegistry)
local EntityEntityFactory = require(script.Parent.Infrastructure.ECS.EntityEntityFactory)
local EntitySystemRegistry = require(script.Parent.Infrastructure.ECS.EntitySystemRegistry)
local EntityCoreSchema = require(script.Parent.Infrastructure.ECS.Schemas.EntityCoreSchema)
local EntityProofSchema = require(script.Parent.Infrastructure.ECS.Schemas.EntityProofSchema)
local EntityReplicationRegistry = require(script.Parent.Infrastructure.Replication.EntityReplicationRegistry)
local EntityReplicationService = require(script.Parent.Infrastructure.Replication.EntityReplicationService)
local EntityInstanceBindingRegistry = require(script.Parent.Infrastructure.Runtime.EntityInstanceBindingRegistry)
local EntityInstanceBindingService = require(script.Parent.Infrastructure.Runtime.EntityInstanceBindingService)
local EntityRevealService = require(script.Parent.Infrastructure.Runtime.EntityRevealService)
local EntityRuntimeParticipationService = require(script.Parent.Infrastructure.Runtime.EntityRuntimeParticipationService)
local EntityRuntimeSnapshotBuilder = require(script.Parent.Infrastructure.Runtime.EntityRuntimeSnapshotBuilder)
local EntityRuntimeSyncService = require(script.Parent.Infrastructure.Runtime.EntityRuntimeSyncService)
local EntitySyncContributorRegistry = require(script.Parent.Infrastructure.Runtime.EntitySyncContributorRegistry)
local EntityLifecycleStateMachine = require(script.Parent.Infrastructure.Services.EntityLifecycleStateMachine)

type TEntityLifecycleState =
	"Uninitialized"
	| "RegisteringECS"
	| "CompilingECS"
	| "ReadyForRuntimeRegistration"
	| "RegisteringRuntime"
	| "ReadyForAIRegistration"
	| "RegisteringAI"
	| "Running"
	| "ShuttingDown"
	| "Destroyed"

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

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "ClientSignals",
		Factory = function(service: any, _baseContext: any)
			return service.Client
		end,
	},
	{
		Name = "EntityLifecycleStateMachine",
		Module = EntityLifecycleStateMachine,
		CacheAs = "_lifecycle",
	},
	{
		Name = "EntitySchemaRegistry",
		Module = EntitySchemaRegistry,
		CacheAs = "_schemaRegistry",
	},
	{
		Name = "EntityEntityFactory",
		Module = EntityEntityFactory,
		CacheAs = "_entityFactory",
	},
	{
		Name = "EntityInstanceBindingRegistry",
		Module = EntityInstanceBindingRegistry,
		CacheAs = "_instanceBindingRegistry",
	},
	{
		Name = "EntityRevealService",
		Module = EntityRevealService,
		CacheAs = "_revealService",
	},
	{
		Name = "EntityRuntimeSnapshotBuilder",
		Module = EntityRuntimeSnapshotBuilder,
		CacheAs = "_runtimeSnapshotBuilder",
	},
	{
		Name = "EntityRuntimeParticipationService",
		Module = EntityRuntimeParticipationService,
		CacheAs = "_runtimeParticipation",
	},
	{
		Name = "EntityInstanceBindingService",
		Module = EntityInstanceBindingService,
		CacheAs = "_instanceBindingService",
	},
	{
		Name = "EntityRuntimeSyncService",
		Module = EntityRuntimeSyncService,
		CacheAs = "_runtimeSyncService",
	},
	{
		Name = "EntitySyncContributorRegistry",
		Module = EntitySyncContributorRegistry,
		CacheAs = "_syncContributorRegistry",
	},
	{
		Name = "EntityReplicationRegistry",
		Module = EntityReplicationRegistry,
		CacheAs = "_replicationRegistry",
	},
	{
		Name = "EntityReplicationService",
		Module = EntityReplicationService,
		CacheAs = "_replicationService",
	},
	{
		Name = "EntityAIActorTypeRegistry",
		Module = EntityAIActorTypeRegistry,
		CacheAs = "_aiActorTypeRegistry",
	},
	{
		Name = "EntityAIEntityRegistry",
		Module = EntityAIEntityRegistry,
		CacheAs = "_aiEntityRegistry",
	},
	{
		Name = "EntityCombatAIRuntimeBridge",
		Module = EntityCombatAIRuntimeBridge,
		CacheAs = "_combatAIRuntimeBridge",
	},
	{
		Name = "EntitySystemRegistry",
		Module = EntitySystemRegistry,
		CacheAs = "_systemRegistry",
	},
}

local EntityModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
}

local EntityContext = Knit.CreateService({
	Name = "EntityContext",
	Client = {
		EntityBootstrap = Knit.CreateSignal(),
		EntityReliable = Knit.CreateSignal(),
		EntityUnreliable = Knit.CreateSignal(),
		EntityEntity = Knit.CreateSignal(),
	},
	WorldService = {
		Name = "EntityECSWorldService",
		Module = EntityECSWorldService,
		CacheAs = "_worldService",
	},
	Modules = EntityModules,
	StartOrder = { "Infrastructure" },
	ExternalServices = {
		{ Name = "CombatContext", CacheAs = "_combatContext" },
	},
	Teardown = {},
})

local EntityBaseContext = BaseContext.new(EntityContext)

function EntityContext:KnitInit()
	EntityBaseContext:KnitInit()
	self._schedulerTickBound = false
	self._lastStartupFailure = nil
	self._runtimeTickActive = false
	self:_BindLifecycleHooks()

	local initResult = self:Init()
	if not initResult.success then
		error(("EntityContext failed to initialize: [%s] %s"):format(tostring(initResult.type), tostring(initResult.message)))
	end
end

function EntityContext:KnitStart()
	EntityBaseContext:KnitStart()

	local startResult = self:Start()
	if not startResult.success then
		error(("EntityContext failed to start: [%s] %s"):format(tostring(startResult.type), tostring(startResult.message)))
	end
end

function EntityContext:Init(_registry: any?, _name: string?): Result.Result<boolean>
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

		return self:_BuildInvalidLifecycleStateError(
			"Init",
			{
				"Uninitialized",
				"RegisteringECS",
				"CompilingECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
			}
		)
	end, "EntityContext:Init")
end

function EntityContext:Start(): Result.Result<boolean>
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

		return self:_BuildInvalidLifecycleStateError(
			"Start",
			{
				"RegisteringECS",
				"CompilingECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
			}
		)
	end, "EntityContext:Start")
end

function EntityContext:GetLifecycleState(): Result.Result<TEntityLifecycleState>
	return Catch(function()
		return Ok(self._lifecycle:GetState())
	end, "EntityContext:GetLifecycleState")
end

function EntityContext:GetReadinessStatus(): Result.Result<any>
	return Catch(function()
		return Ok(self:_BuildReadinessStatus())
	end, "EntityContext:GetReadinessStatus")
end

function EntityContext:GetRegistrationStatus(): Result.Result<any>
	return Catch(function()
		return Ok(self:_BuildReadinessStatus())
	end, "EntityContext:GetRegistrationStatus")
end

function EntityContext:RunAcceptanceCheck(): Result.Result<any>
	return Catch(function()
		local readinessStatus = self:_BuildReadinessStatus()
		local acceptanceReport = table.clone(readinessStatus.Acceptance)
		acceptanceReport.LifecycleState = readinessStatus.LifecycleState
		return Ok(acceptanceReport)
	end, "EntityContext:RunAcceptanceCheck")
end

function EntityContext:RunOperationalProof(): Result.Result<any>
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

		local bindResult = self:BindEntityInstance(proofEntity)
		proofResult.Runtime.BindPassed = bindResult.success and bindResult.value ~= nil

		local registerRuntimeResult = self:RegisterRuntimeEntity(proofEntity)
		runtimeRegistered = registerRuntimeResult.success

		local aiRegistrationResult = self:RegisterAIEntity(proofEntity, PROOF_ACTOR_TYPE)
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
	end, "EntityContext:RunOperationalProof")
end

function EntityContext:RegisterFeatureSchema(featureName: string, schema: any): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterFeatureSchema", { "RegisteringECS" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._schemaRegistry:RegisterFeatureSchema(featureName, schema)
	end, "EntityContext:RegisterFeatureSchema")
end

function EntityContext:Get(entity: number, key: string, featureName: string?): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"Get",
			{
				"RegisteringECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
				"ShuttingDown",
			}
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Get(entity, key, featureName)
	end, "EntityContext:Get")
end

function EntityContext:Set(entity: number, key: string, value: any, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"Set",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Set(entity, key, value, featureName)
	end, "EntityContext:Set")
end

function EntityContext:Add(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"Add",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Add(entity, key, featureName)
	end, "EntityContext:Add")
end

function EntityContext:Remove(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"Remove",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Remove(entity, key, featureName)
	end, "EntityContext:Remove")
end

function EntityContext:Has(entity: number, key: string, featureName: string?): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"Has",
			{
				"RegisteringECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
				"ShuttingDown",
			}
		)
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
	end, "EntityContext:Has")
end

function EntityContext:Query(querySpec: any): Result.Result<{ number }>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"Query",
			{
				"RegisteringECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
				"ShuttingDown",
			}
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:Query(querySpec)
	end, "EntityContext:Query")
end

function EntityContext:RegisterSystem(phaseName: string, systemSpec: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterSystem", { "RegisteringECS" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RegisterSystem(phaseName, systemSpec)
	end, "EntityContext:RegisterSystem")
end

function EntityContext:TickPhase(phaseName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("TickPhase", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RunPhase(phaseName)
	end, "EntityContext:TickPhase")
end

function EntityContext:TickAll(): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("TickAll", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._systemRegistry:RunAllPhases()
	end, "EntityContext:TickAll")
end

function EntityContext:CreateEntity(archetypeName: string, payload: { [string]: any }?): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"CreateEntity",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:CreateFromArchetype(archetypeName, payload)
	end, "EntityContext:CreateEntity")
end

function EntityContext:DestroyEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("DestroyEntity", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local prepareRemovalResult = self:_PrepareRuntimeEntityForRemoval(entity, true)
		if not prepareRemovalResult.success then
			return prepareRemovalResult
		end

		return self._entityFactory:DeleteEntityNow(entity)
	end, "EntityContext:DestroyEntity")
end

function EntityContext:MarkForDestruction(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"MarkForDestruction",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local prepareRemovalResult = self:_PrepareRuntimeEntityForRemoval(entity, true)
		if not prepareRemovalResult.success then
			return prepareRemovalResult
		end

		return self._entityFactory:MarkEntityForDestruction(entity)
	end, "EntityContext:MarkForDestruction")
end

function EntityContext:FlushDestructionQueue(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushDestructionQueue", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._entityFactory:FlushDestroyQueue()
	end, "EntityContext:FlushDestructionQueue")
end

function EntityContext:EnableRuntimeBinding(featureName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"EnableRuntimeBinding",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if self._instanceBindingRegistry:GetBinding(featureName) == nil then
			return Result.Err("UnknownInstanceBinding", Errors.UNKNOWN_INSTANCE_BINDING, {
				FeatureName = featureName,
			})
		end

		return self._runtimeParticipation:EnableFeature("Binding", featureName)
	end, "EntityContext:EnableRuntimeBinding")
end

function EntityContext:EnableRuntimeSync(featureName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"EnableRuntimeSync",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if self._syncContributorRegistry:GetSyncContributor(featureName) == nil then
			return Result.Err("UnknownSyncContributor", Errors.UNKNOWN_SYNC_CONTRIBUTOR, {
				FeatureName = featureName,
			})
		end

		return self._runtimeParticipation:EnableFeature("Sync", featureName)
	end, "EntityContext:EnableRuntimeSync")
end

function EntityContext:EnableRuntimeReplication(featureName: string): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"EnableRuntimeReplication",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		if self._replicationRegistry:GetReplicationSurface(featureName) == nil then
			return Result.Err("UnknownReplicationSurface", Errors.UNKNOWN_REPLICATION_SURFACE, {
				FeatureName = featureName,
			})
		end

		local enableTransportResult = self._replicationService:EnableFeature(self, featureName)
		if not enableTransportResult.success then
			return enableTransportResult
		end

		return self._runtimeParticipation:EnableFeature("Replication", featureName)
	end, "EntityContext:EnableRuntimeReplication")
end

function EntityContext:RegisterRuntimeEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RegisterRuntimeEntity", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local registerResult = self._runtimeParticipation:RegisterRuntimeEntity(entity)
		if not registerResult.success then
			return registerResult
		end

		if self._instanceBindingService:GetBoundInstance(entity) ~= nil then
			local onBoundResult = self:_OnRuntimeEntityBound(entity)
			if not onBoundResult.success then
				return onBoundResult
			end
		end

		return Ok(true)
	end, "EntityContext:RegisterRuntimeEntity")
end

function EntityContext:UnregisterRuntimeEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("UnregisterRuntimeEntity", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local prepareRemovalResult = self:_PrepareRuntimeEntityForRemoval(entity, true)
		if not prepareRemovalResult.success then
			return prepareRemovalResult
		end

		return Ok(true)
	end, "EntityContext:UnregisterRuntimeEntity")
end

function EntityContext:GetWorld(): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetWorld",
			{
				"Uninitialized",
				"RegisteringECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
				"ShuttingDown",
			}
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._worldService:GetWorld())
	end, "EntityContext:GetWorld")
end

function EntityContext:GetFeatureComponents(featureName: string): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetFeatureComponents",
			{
				"Uninitialized",
				"RegisteringECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
				"ShuttingDown",
			}
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._schemaRegistry:GetFeatureComponents(featureName)
	end, "EntityContext:GetFeatureComponents")
end

function EntityContext:GetEntityFactory(): Result.Result<any>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetEntityFactory",
			{
				"Uninitialized",
				"RegisteringECS",
				"ReadyForRuntimeRegistration",
				"RegisteringRuntime",
				"ReadyForAIRegistration",
				"RegisteringAI",
				"Running",
				"ShuttingDown",
			}
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._entityFactory)
	end, "EntityContext:GetEntityFactory")
end

function EntityContext:RegisterInstanceBinding(featureName: string, binding: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"RegisterInstanceBinding",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local bindingResult = self._instanceBindingRegistry:RegisterBinding(featureName, binding)
		if not bindingResult.success then
			return bindingResult
		end

		if self._lifecycle:GetState() == "ReadyForRuntimeRegistration" then
			local transitionResult = self._lifecycle:BeginRuntimeRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Ok(true)
	end, "EntityContext:RegisterInstanceBinding")
end

function EntityContext:BindEntityInstance(entity: number): Result.Result<Instance?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("BindEntityInstance", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local requireRuntimeResult = self:_RequireRuntimeBindingParticipation(entity)
		if not requireRuntimeResult.success then
			return requireRuntimeResult
		end

		local bindResult = self._instanceBindingService:BindEntityInstance(self, entity)
		if not bindResult.success then
			return bindResult
		end

		local onBoundResult = self:_OnRuntimeEntityBound(entity)
		if not onBoundResult.success then
			return onBoundResult
		end

		return bindResult
	end, "EntityContext:BindEntityInstance")
end

function EntityContext:UnbindEntityInstance(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("UnbindEntityInstance", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._instanceBindingService:UnbindEntityInstance(entity)
	end, "EntityContext:UnbindEntityInstance")
end

function EntityContext:QueueEntityBind(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("QueueEntityBind", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local requireRuntimeResult = self:_RequireRuntimeBindingParticipation(entity)
		if not requireRuntimeResult.success then
			return requireRuntimeResult
		end

		return self._instanceBindingService:QueueEntityBind(entity)
	end, "EntityContext:QueueEntityBind")
end

function EntityContext:FlushBindQueue(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushBindQueue", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._instanceBindingService:FlushBindQueue(self, function(entity: number, _instance: Instance)
			local onBoundResult = self:_OnRuntimeEntityBound(entity)
			if not onBoundResult.success then
				Result.MentionError("EntityContext:Runtime", "Failed to activate bound runtime entity", {
					Entity = entity,
					CauseType = onBoundResult.type,
					CauseMessage = onBoundResult.message,
					Details = onBoundResult.data,
				}, onBoundResult.type)
			end
		end)
	end, "EntityContext:FlushBindQueue")
end

function EntityContext:GetBoundInstance(entity: number): Result.Result<Instance?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetBoundInstance",
			{ "ReadyForAIRegistration", "RegisteringAI", "Running", "ShuttingDown" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._instanceBindingService:GetBoundInstance(entity))
	end, "EntityContext:GetBoundInstance")
end

function EntityContext:GetBoundEntity(instance: Instance): Result.Result<number?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetBoundEntity",
			{ "ReadyForAIRegistration", "RegisteringAI", "Running", "ShuttingDown" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._instanceBindingService:GetBoundEntity(instance))
	end, "EntityContext:GetBoundEntity")
end

function EntityContext:BuildRuntimeSnapshot(entity: number): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"BuildRuntimeSnapshot",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running", "ShuttingDown" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSnapshotBuilder:BuildSnapshot(entity)
	end, "EntityContext:BuildRuntimeSnapshot")
end

function EntityContext:RegisterSyncContributor(featureName: string, payload: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"RegisterSyncContributor",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local contributorResult = self._syncContributorRegistry:RegisterSyncContributor(featureName, payload)
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
	end, "EntityContext:RegisterSyncContributor")
end

function EntityContext:GetSyncContributor(featureName: string): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetSyncContributor",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running", "ShuttingDown" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._syncContributorRegistry:GetSyncContributor(featureName))
	end, "EntityContext:GetSyncContributor")
end

function EntityContext:RegisterReplicationSurface(featureName: string, payload: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"RegisterReplicationSurface",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local surfaceResult = self._replicationRegistry:RegisterReplicationSurface(featureName, payload)
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
	end, "EntityContext:RegisterReplicationSurface")
end

function EntityContext:RunRuntimeSync(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RunRuntimeSync", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSyncService:RunRuntimeSync(self)
	end, "EntityContext:RunRuntimeSync")
end

function EntityContext:RunRuntimePoll(): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("RunRuntimePoll", { "Running" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._runtimeSyncService:RunRuntimePoll(self)
	end, "EntityContext:RunRuntimePoll")
end

function EntityContext:GetReplicationSurface(featureName: string): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetReplicationSurface",
			{ "ReadyForRuntimeRegistration", "RegisteringRuntime", "ReadyForAIRegistration", "RegisteringAI", "Running", "ShuttingDown" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return Ok(self._replicationRegistry:GetReplicationSurface(featureName))
	end, "EntityContext:GetReplicationSurface")
end

function EntityContext:HydrateEntityReplication(player: Player): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("HydrateEntityReplication", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:HydratePlayerResult(player)
	end, "EntityContext:HydrateEntityReplication")
end

function EntityContext:CompleteEntityReplicationBootstrap(player: Player): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"CompleteEntityReplicationBootstrap",
			{ "Running", "ShuttingDown" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:CompleteBootstrapResult(player)
	end, "EntityContext:CompleteEntityReplicationBootstrap")
end

function EntityContext:FlushEntityReplicationReliable(): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushEntityReplicationReliable", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushReliableResult()
	end, "EntityContext:FlushEntityReplicationReliable")
end

function EntityContext:FlushEntityReplicationUnreliable(): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult =
			self:_RequireLifecycleStates("FlushEntityReplicationUnreliable", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushUnreliableResult()
	end, "EntityContext:FlushEntityReplicationUnreliable")
end

function EntityContext:FlushEntityReplicationEntity(entity: number): Result.Result<number>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates("FlushEntityReplicationEntity", { "Running", "ShuttingDown" })
		if not lifecycleResult.success then
			return lifecycleResult
		end

		return self._replicationService:FlushEntityResult(entity)
	end, "EntityContext:FlushEntityReplicationEntity")
end

function EntityContext:RegisterAIActorType(payload: any): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"RegisterAIActorType",
			{ "ReadyForAIRegistration", "RegisteringAI" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local compiledActorTypeResult = self._aiActorTypeRegistry:RegisterActorType(payload)
		if not compiledActorTypeResult.success then
			return compiledActorTypeResult
		end

		local bridgeResult = self._combatAIRuntimeBridge:RegisterActorType(compiledActorTypeResult.value)
		if not bridgeResult.success then
			self._aiActorTypeRegistry:RemoveCompiledActorType(
				compiledActorTypeResult.value.RuntimeKind,
				compiledActorTypeResult.value.ActorType
			)
			return bridgeResult
		end

		if self._lifecycle:GetState() == "ReadyForAIRegistration" then
			local transitionResult = self._lifecycle:BeginAIRegistration()
			if not transitionResult.success then
				return transitionResult
			end
		end

		return Ok(true)
	end, "EntityContext:RegisterAIActorType")
end

function EntityContext:RegisterAIEntity(entity: number, actorType: string): Result.Result<string>
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
			local defaultActionStateResult = self:_WriteAIActionState(entity, self:_BuildDefaultAIActionState(os.clock()))
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
	end, "EntityContext:RegisterAIEntity")
end

function EntityContext:UnregisterAIEntity(entity: number): Result.Result<boolean>
	return Catch(function()
		local lifecycleResult =
			self:_RequireLifecycleStates("UnregisterAIEntity", { "RegisteringAI", "Running", "ShuttingDown" })
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
	end, "EntityContext:UnregisterAIEntity")
end

function EntityContext:GetAIActorHandle(entity: number): Result.Result<string?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetAIActorHandle",
			{ "ReadyForAIRegistration", "RegisteringAI", "Running", "ShuttingDown" }
		)
		if not lifecycleResult.success then
			return lifecycleResult
		end

		local actorHandleResult = self:_ReadAIActorHandle(entity)
		if actorHandleResult.success and actorHandleResult.value ~= nil then
			return actorHandleResult
		end

		return Ok(self._aiEntityRegistry:GetAIActorHandle(entity))
	end, "EntityContext:GetAIActorHandle")
end

function EntityContext:GetAIRegistration(entity: number): Result.Result<any?>
	return Catch(function()
		local lifecycleResult = self:_RequireLifecycleStates(
			"GetAIRegistration",
			{ "ReadyForAIRegistration", "RegisteringAI", "Running", "ShuttingDown" }
		)
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
	end, "EntityContext:GetAIRegistration")
end

function EntityContext:Destroy(): Result.Result<boolean>
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
				return self:_BuildInvalidLifecycleStateError("Destroy", {
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

		local destroyResult = EntityBaseContext:Destroy()
		if not destroyResult.success then
			return destroyResult
		end

		return Ok(true)
	end, "EntityContext:Destroy")
end

function EntityContext:_BindLifecycleHooks()
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

function EntityContext:_RegisterBuiltInSchemas(): Result.Result<boolean>
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

function EntityContext:_EnsureBuiltInOperationalProofRuntime(): Result.Result<boolean>
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
	end, "EntityContext:_EnsureBuiltInOperationalProofRuntime")
end

function EntityContext:_EnsureBuiltInOperationalProofActorType(): Result.Result<boolean>
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
	end, "EntityContext:_EnsureBuiltInOperationalProofActorType")
end

function EntityContext:_BeginECSCompile(): Result.Result<boolean>
	return Catch(function()
		local transitionResult = self._lifecycle:BeginECSCompile()
		if not transitionResult.success then
			return transitionResult
		end

		return self._schemaRegistry:BeginCompile()
	end, "EntityContext:_BeginECSCompile")
end

function EntityContext:_CompileECSKernel(): Result.Result<boolean>
	return Catch(function()
		return self._schemaRegistry:ValidateReady()
	end, "EntityContext:_CompileECSKernel")
end

function EntityContext:_FinalizeECSKernel(): Result.Result<boolean>
	return Catch(function()
		local closeSystemResult = self._systemRegistry:CloseRegistration()
		if not closeSystemResult.success then
			return closeSystemResult
		end

		return self._schemaRegistry:FinalizeCompile()
	end, "EntityContext:_FinalizeECSKernel")
end

function EntityContext:_FinalizeRuntimeRegistrations(): Result.Result<boolean>
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
	end, "EntityContext:_FinalizeRuntimeRegistrations")
end

function EntityContext:_FinalizeAIRegistrations(): Result.Result<boolean>
	return Catch(function()
		return self._aiActorTypeRegistry:CloseRegistration()
	end, "EntityContext:_FinalizeAIRegistrations")
end

function EntityContext:_BindSchedulerTick()
	if self._schedulerTickBound then
		return
	end

	self._schedulerTickBound = true
	EntityBaseContext:RegisterSchedulerSystem(EntityPhases.SchedulerPhase, function()
		self:_RunScheduledTick()
	end)
end

function EntityContext:_RunScheduledTick()
	if self._lifecycle:GetState() ~= "Running" then
		self._runtimeTickActive = false
		return
	end

	self._runtimeTickActive = true

	local bindResult = self:FlushBindQueue()
	if not bindResult.success then
		Result.MentionError("EntityContext:RunScheduledTick", "Entity bind queue flush failed", {
			CauseType = bindResult.type,
			CauseMessage = bindResult.message,
			Details = bindResult.data,
		}, bindResult.type)
	end

	local runResult = self._systemRegistry:RunAllPhases()
	if not runResult.success then
		Result.MentionError("EntityContext:RunScheduledTick", "Entity system tick failed", {
			CauseType = runResult.type,
			CauseMessage = runResult.message,
			Details = runResult.data,
		}, runResult.type)
	end

	local syncResult = self:RunRuntimeSync()
	if not syncResult.success then
		Result.MentionError("EntityContext:RunScheduledTick", "Entity runtime sync failed", {
			CauseType = syncResult.type,
			CauseMessage = syncResult.message,
			Details = syncResult.data,
		}, syncResult.type)
	end

	local pollResult = self:RunRuntimePoll()
	if not pollResult.success then
		Result.MentionError("EntityContext:RunScheduledTick", "Entity runtime poll failed", {
			CauseType = pollResult.type,
			CauseMessage = pollResult.message,
			Details = pollResult.data,
		}, pollResult.type)
	end

	local reliableResult = self:FlushEntityReplicationReliable()
	if not reliableResult.success then
		Result.MentionError("EntityContext:RunScheduledTick", "Entity reliable replication flush failed", {
			CauseType = reliableResult.type,
			CauseMessage = reliableResult.message,
			Details = reliableResult.data,
		}, reliableResult.type)
	end

	local unreliableResult = self:FlushEntityReplicationUnreliable()
	if not unreliableResult.success then
		Result.MentionError("EntityContext:RunScheduledTick", "Entity unreliable replication flush failed", {
			CauseType = unreliableResult.type,
			CauseMessage = unreliableResult.message,
			Details = unreliableResult.data,
		}, unreliableResult.type)
	end
end

function EntityContext:_FlushPendingDestructionDuringShutdown()
	local flushResult = self._entityFactory:FlushDestroyQueue()
	if not flushResult.success then
		Result.MentionError("EntityContext:Shutdown", "Failed to flush destruction queue during shutdown", {
			CauseType = flushResult.type,
			CauseMessage = flushResult.message,
			Details = flushResult.data,
		}, flushResult.type)
	end
end

function EntityContext:_ValidateKernelReadyForStart(): Result.Err?
	local schemaResult = self._schemaRegistry:ValidateReady()
	if not schemaResult.success then
		return schemaResult
	end

	local systemResult = self._systemRegistry:ValidateReady()
	if not systemResult.success then
		return systemResult
	end

	return nil
end

function EntityContext:_ValidateRuntimeBridgeReadyForAIRegistration(): Result.Err?
	local bindingResult = self._instanceBindingRegistry:ValidateReady()
	if not bindingResult.success then
		return bindingResult
	end

	local syncContributorResult = self._syncContributorRegistry:ValidateReady()
	if not syncContributorResult.success then
		return syncContributorResult
	end

	local replicationResult = self._replicationRegistry:ValidateReady()
	if not replicationResult.success then
		return replicationResult
	end

	return nil
end

function EntityContext:_ValidateAIRegistrationReadyForRun(): Result.Err?
	local actorTypeStatus = self._aiActorTypeRegistry:GetStatus()
	if actorTypeStatus.ActorTypeCount <= 0 then
		return Result.Err("MissingRequiredAIActorType", Errors.MISSING_REQUIRED_AI_ACTOR_TYPE, {
			ActorTypeCount = actorTypeStatus.ActorTypeCount,
		})
	end

	local actorTypeRegistryResult = self._aiActorTypeRegistry:ValidateReady()
	if not actorTypeRegistryResult.success then
		return actorTypeRegistryResult
	end

	local aiBridgeResult = self._combatAIRuntimeBridge:ValidateReady()
	if not aiBridgeResult.success then
		return aiBridgeResult
	end

	return nil
end

function EntityContext:_HandleStartupFailure()
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

function EntityContext:_RequireRuntimeBindingParticipation(entity: number): Result.Result<boolean>
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

function EntityContext:_OnRuntimeEntityBound(entity: number): Result.Result<boolean>
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
	end, "EntityContext:_OnRuntimeEntityBound")
end

function EntityContext:_PrepareRuntimeEntityForRemoval(entity: number, unregisterRuntimeEntity: boolean): Result.Result<boolean>
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
	end, "EntityContext:_PrepareRuntimeEntityForRemoval")
end

function EntityContext:_ShutdownRuntimeExecution()
	for _, entity in ipairs(self._aiEntityRegistry:CollectRegisteredEntities()) do
		self:UnregisterAIEntity(entity)
	end

	for _, entity in ipairs(self._runtimeParticipation:CollectRuntimeEntities()) do
		self:_PrepareRuntimeEntityForRemoval(entity, true)
	end

	self._instanceBindingService:DestroyAll()
end

function EntityContext:_BuildCombatAIActorAdapter(registration: any): any
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

function EntityContext:_IsAIRegistrationActive(registration: any): boolean
	local didCheck, isActive = pcall(registration.CompiledActorType.IsEntityActive, self, registration.Entity)
	if not didCheck then
		Result.MentionError("EntityContext:AI", "AI active callback failed", {
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

function EntityContext:_GetAIRegistrationActorLabel(registration: any): string?
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

function EntityContext:_BuildAIRegistrationFacts(registration: any, currentTime: number): { [string]: any }
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
		Result.MentionError("EntityContext:AI", "AI facts resolver failed", {
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

function EntityContext:_BuildAIRegistrationServices(
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
		Result.MentionError("EntityContext:AI", "AI services resolver failed", {
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

function EntityContext:_RunAIRegistrationCallback(registration: any, callbackName: string, callbackArgument: any?)
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

	Result.MentionError("EntityContext:AI", "AI registration callback failed", {
		ActorType = registration.CompiledActorType.ActorType,
		ActorHandle = registration.ActorHandle,
		Entity = registration.Entity,
		RuntimeKind = registration.RuntimeKind,
		Stage = callbackName,
		CauseMessage = callbackError,
	}, "EntityAIRegistrationCallbackFailed")
end

function EntityContext:_CleanupAIRegistration(registration: any, removeRegistration: boolean)
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

function EntityContext:_WriteAIRegistrationRuntimeState(
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
	end, "EntityContext:_WriteAIRegistrationRuntimeState")
end

function EntityContext:_WriteAIActionState(entity: number, actionState: any): Result.Result<boolean>
	return self._entityFactory:Set(entity, "AIActionState", actionState)
end

function EntityContext:_WriteAIActionStateFromCombatState(
	entity: number,
	combatActionState: any,
	timestamp: number
): Result.Result<boolean>
	local mappedState = self:_MapCombatActionStateToEntityActionState(combatActionState, timestamp)
	return self:_WriteAIActionState(entity, mappedState)
end

function EntityContext:_ClearAIRegistrationRuntimeState(entity: number): Result.Result<boolean>
	return Catch(function()
		local componentKeys = { "AIActionState", "AIRegistration", "AIBehaviorConfig", "AIRuntimeProfile", "AIActorType" }
		for _, componentKey in ipairs(componentKeys) do
			local removeResult = self._entityFactory:Remove(entity, componentKey)
			if not removeResult.success then
				return removeResult
			end
		end

		return Ok(true)
	end, "EntityContext:_ClearAIRegistrationRuntimeState")
end

function EntityContext:_ReadAIActorHandle(entity: number): Result.Result<string?>
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
	end, "EntityContext:_ReadAIActorHandle")
end

function EntityContext:_ReadAIRegistrationRuntimeState(entity: number): Result.Result<any?>
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
	end, "EntityContext:_ReadAIRegistrationRuntimeState")
end

function EntityContext:_BuildDefaultAIActionState(timestamp: number): any
	return {
		Status = "Idle",
		ActionName = nil,
		StartedAt = nil,
		UpdatedAt = timestamp,
		ErrorCode = nil,
	}
end

function EntityContext:_MapCombatActionStateToEntityActionState(combatActionState: any, timestamp: number): any
	if type(combatActionState) ~= "table" then
		return self:_BuildDefaultAIActionState(timestamp)
	end

	return {
		Status = combatActionState.ActionState or "Idle",
		ActionName = combatActionState.CurrentActionId or combatActionState.PendingActionId,
		StartedAt = combatActionState.StartedAt,
		UpdatedAt = timestamp,
		ErrorCode = nil,
	}
end

function EntityContext:_RequireLifecycleStates(methodName: string, expectedStates: { TEntityLifecycleState }): Result.Result<boolean>
	local currentState = self._lifecycle:GetState()
	for _, expectedState in ipairs(expectedStates) do
		if currentState == expectedState then
			return Ok(true)
		end
	end

	return self:_BuildInvalidLifecycleStateError(methodName, expectedStates)
end

function EntityContext:_BuildInvalidLifecycleStateError(
	methodName: string,
	expectedStates: { TEntityLifecycleState }
): Result.Err
	return Result.Err("InvalidEntityLifecycleState", Errors.INVALID_LIFECYCLE_STATE, {
		MethodName = methodName,
		CurrentState = self._lifecycle:GetState(),
		ExpectedStates = table.clone(expectedStates),
	})
end

function EntityContext:_BuildReadinessStatus(): any
	local lifecycleState = self._lifecycle:GetState()
	local schemaStatus = self._schemaRegistry:GetStatus()
	local systemStatus = self._systemRegistry:GetStatus()
	local instanceBindingRegistryStatus = self._instanceBindingRegistry:GetStatus()
	local syncContributorRegistryStatus = self._syncContributorRegistry:GetStatus()
	local replicationRegistryStatus = self._replicationRegistry:GetStatus()
	local aiActorTypeRegistryStatus = self._aiActorTypeRegistry:GetStatus()
	local aiBridgeStatus = self._combatAIRuntimeBridge:GetStatus()
	local replicationServiceStatus = self._replicationService:GetStatus()
	local instanceBindingServiceStatus = self._instanceBindingService:GetStatus()
	local runtimeParticipationStatus = self._runtimeParticipation:GetStatus()
	local aiEntityRegistryStatus = self._aiEntityRegistry:GetStatus()

	local schemaReady = self._schemaRegistry:ValidateReady().success
	local systemReady = self._systemRegistry:ValidateReady().success
	local runtimeBindingsReady = self._instanceBindingRegistry:ValidateReady().success
	local runtimeSyncReady = self._syncContributorRegistry:ValidateReady().success
	local runtimeReplicationReady = self._replicationRegistry:ValidateReady().success
	local aiActorTypesReady = self._aiActorTypeRegistry:ValidateReady().success
	local aiBridgeReady = self._combatAIRuntimeBridge:ValidateReady().success

	local status = {
		LifecycleState = lifecycleState,
		ECS = {
			RegistrationClosed = schemaStatus.RegistrationClosed,
			CompileStarted = schemaStatus.CompileStarted,
			Compiled = schemaStatus.Compiled,
			CoreSchemaRegistered = schemaStatus.CoreSchemaRegistered,
			SystemsClosed = systemStatus.RegistrationClosed,
			Ready = schemaReady and systemReady,
			FeatureSchemaCount = schemaStatus.FeatureSchemaCount,
			ArchetypeCount = schemaStatus.ArchetypeCount,
			RegisteredSystemCount = systemStatus.RegisteredSystemCount,
		},
		Runtime = {
			BindingsClosed = instanceBindingRegistryStatus.RegistrationClosed,
			SyncClosed = syncContributorRegistryStatus.RegistrationClosed,
			ReplicationClosed = replicationRegistryStatus.RegistrationClosed,
			Ready = runtimeBindingsReady
				and runtimeSyncReady
				and runtimeReplicationReady
				and replicationServiceStatus.BootCapable,
			BindingCount = instanceBindingRegistryStatus.BindingCount,
			SyncContributorCount = syncContributorRegistryStatus.ContributorCount,
			ReplicationSurfaceCount = replicationRegistryStatus.SurfaceCount,
			RuntimeEntityCount = runtimeParticipationStatus.RuntimeEntityCount,
			EnabledFeatures = runtimeParticipationStatus.EnabledFeatures,
			BoundEntityCount = instanceBindingServiceStatus.BoundEntityCount,
			PendingBindCount = instanceBindingServiceStatus.PendingBindCount,
		},
		AI = {
			ActorTypesClosed = aiActorTypeRegistryStatus.RegistrationClosed,
			BridgeReady = aiBridgeReady and aiBridgeStatus.Ready,
			Ready = aiActorTypesReady and aiBridgeReady,
			ActorTypeCount = aiActorTypeRegistryStatus.ActorTypeCount,
			ActorTypesRequired = true,
			StartupGateSatisfied = aiActorTypeRegistryStatus.ActorTypeCount > 0,
			RuntimeRegistrationCount = aiEntityRegistryStatus.RegistrationCount,
			ResolverDependencyMode = aiActorTypeRegistryStatus.DependencyMode,
			AllowsRuntimeServices = aiActorTypeRegistryStatus.AllowsRuntimeServices,
		},
		Execution = {
			SchedulerBound = self._schedulerTickBound,
			RuntimeTickActive = self._runtimeTickActive and lifecycleState == "Running",
			ShutdownStarted = lifecycleState == "ShuttingDown" or lifecycleState == "Destroyed",
			Destroyed = lifecycleState == "Destroyed",
			ReplicationBootCapable = replicationServiceStatus.BootCapable,
			HasAppliedReplicationSchema = replicationServiceStatus.HasAppliedSharedSchema,
			LastStartupFailure = self._lastStartupFailure,
		},
	}

	status.Acceptance = self:_BuildAcceptanceReport(status)
	return table.freeze(status)
end

function EntityContext:_BuildAcceptanceReport(status: any): any
	local blockingGaps = {}

	local function addBlockingGap(code: string, message: string, details: any?)
		table.insert(blockingGaps, {
			Code = code,
			Message = message,
			Details = details,
		})
	end

	if status.LifecycleState ~= "Running" then
		addBlockingGap("LifecycleNotRunning", "EntityContext is not in the Running lifecycle state", {
			LifecycleState = status.LifecycleState,
		})
	end

	if not status.ECS.CoreSchemaRegistered then
		addBlockingGap("MissingCoreSchema", "EntityContext core schema is not registered")
	end
	if not status.ECS.Compiled then
		addBlockingGap("ECSNotCompiled", "EntityContext ECS kernel has not been finalized")
	end
	if not status.ECS.SystemsClosed then
		addBlockingGap("SystemRegistrationOpen", "Entity system registration is still open")
	end
	if not status.ECS.Ready then
		addBlockingGap("ECSNotReady", "Entity ECS validation has not passed")
	end

	if not status.Runtime.BindingsClosed then
		addBlockingGap("BindingRegistrationOpen", "Entity instance binding registration is still open")
	end
	if not status.Runtime.SyncClosed then
		addBlockingGap("SyncRegistrationOpen", "Entity sync contributor registration is still open")
	end
	if not status.Runtime.ReplicationClosed then
		addBlockingGap("ReplicationRegistrationOpen", "Entity replication surface registration is still open")
	end
	if not status.Runtime.Ready then
		addBlockingGap("RuntimeNotReady", "Entity runtime bridge validation has not passed")
	end

	if not status.AI.ActorTypesClosed then
		addBlockingGap("AIRegistrationOpen", "Entity AI actor type registration is still open")
	end
	if not status.AI.StartupGateSatisfied then
		addBlockingGap("MissingRequiredAIActorType", Errors.MISSING_REQUIRED_AI_ACTOR_TYPE, {
			ActorTypeCount = status.AI.ActorTypeCount,
			ActorTypesRequired = status.AI.ActorTypesRequired,
		})
	end
	if not status.AI.BridgeReady then
		addBlockingGap("AIBridgeNotReady", "Entity AI runtime bridge is not ready")
	end
	if status.AI.ResolverDependencyMode ~= "EntityContextOnly" then
		addBlockingGap("InvalidResolverDependencyMode", "Entity AI resolver contract is not EntityContextOnly")
	end

	if not status.Execution.SchedulerBound then
		addBlockingGap("SchedulerNotBound", "Entity scheduler tick has not been bound")
	end
	if not status.Execution.ReplicationBootCapable then
		addBlockingGap("ReplicationNotBootCapable", "Entity replication shell is not boot-capable")
	end
	if status.Execution.ShutdownStarted then
		addBlockingGap("ShutdownStarted", "EntityContext shutdown has already started")
	end
	if status.Execution.LastStartupFailure ~= nil then
		addBlockingGap("StartupFailureRecorded", "EntityContext recorded a startup failure", status.Execution.LastStartupFailure)
	end

	if status.LifecycleState == "ShuttingDown" or status.LifecycleState == "Destroyed" then
		if status.Runtime.PendingBindCount > 0 then
			addBlockingGap("PendingBindCleanup", "EntityContext still has queued runtime binds", {
				PendingBindCount = status.Runtime.PendingBindCount,
			})
		end
		if status.Runtime.BoundEntityCount > 0 then
			addBlockingGap("BoundInstanceCleanup", "EntityContext still has bound runtime instances", {
				BoundEntityCount = status.Runtime.BoundEntityCount,
			})
		end
		if status.Runtime.RuntimeEntityCount > 0 then
			addBlockingGap("RuntimeEntityCleanup", "EntityContext still has runtime-participating entities", {
				RuntimeEntityCount = status.Runtime.RuntimeEntityCount,
			})
		end
		if status.AI.RuntimeRegistrationCount > 0 then
			addBlockingGap("AIRegistrationCleanup", "EntityContext still has registered AI runtime entities", {
				RuntimeRegistrationCount = status.AI.RuntimeRegistrationCount,
			})
		end
	end

	return table.freeze({
		IsReadyForUse = #blockingGaps == 0,
		BlockingGaps = table.freeze(blockingGaps),
	})
end

function EntityContext:_BuildFailureSummary(failureResult: Result.Result<any>): any
	if failureResult == nil then
		return nil
	end

	return {
		Type = failureResult.type,
		Message = failureResult.message,
		Data = failureResult.data,
	}
end

function EntityContext.Client:RequestEntityReplication(player: Player): boolean
	local result = self.Server:HydrateEntityReplication(player)
	return result.success and result.value == true
end

function EntityContext.Client:AcknowledgeEntityReplicationBootstrap(player: Player): boolean
	local result = self.Server:CompleteEntityReplicationBootstrap(player)
	return result.success and result.value == true
end

return EntityContext
