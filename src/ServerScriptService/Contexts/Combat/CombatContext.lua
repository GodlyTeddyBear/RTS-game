--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local Result = require(ReplicatedStorage.Utilities.Result)

local CombatAbilities = require(script.Parent.Config.CombatAbilities)
local CombatAbilityRegistryService = require(script.Parent.Infrastructure.Services.CombatAbilityRegistryService)
local CombatOutcomeRuleRegistryService = require(script.Parent.Infrastructure.Services.CombatOutcomeRuleRegistryService)
local CombatRequestFactoryService = require(script.Parent.Infrastructure.Services.CombatRequestFactoryService)
local CombatTargetReadService = require(script.Parent.Infrastructure.Services.CombatTargetReadService)
local LockOnService = require(script.Parent.Infrastructure.Services.LockOnService)
local MovementActorReadService = require(script.Parent.Infrastructure.Services.Movement.MovementActorReadService)
local MovementActorSetupService = require(script.Parent.Infrastructure.Services.Movement.MovementActorSetupService)
local MovementApplyBridgeService = require(script.Parent.Infrastructure.Services.Movement.MovementApplyBridgeService)
local MovementFlowDispatchService = require(script.Parent.Infrastructure.Services.Movement.MovementFlowDispatchService)
local MovementFlowSnapshotService = require(script.Parent.Infrastructure.Services.Movement.MovementFlowSnapshotService)
local MovementFlowfieldService = require(script.Parent.Infrastructure.Services.Movement.MovementFlowfieldService)
local MovementGridService = require(script.Parent.Infrastructure.Services.Movement.MovementGridService)
local MovementPathRuntimeService = require(script.Parent.Infrastructure.Services.Movement.MovementPathRuntimeService)
local ProjectileSimulationService = require(script.Parent.Infrastructure.Services.ProjectileSimulationService)
local StatusService = require(script.Parent.Infrastructure.Services.StatusService)
local CombatEntitySchema = require(script.Parent.Infrastructure.Entity.CombatEntitySchema)
local CombatStatusAuraSystem = require(script.Parent.Infrastructure.Systems.Status.CombatStatusAuraSystem)
local MovementSpeedStatusSystem = require(script.Parent.Infrastructure.Systems.Status.MovementSpeedStatusSystem)
local HitboxSimulationService = require(script.Parent.Infrastructure.Services.HitboxSimulationService)
local AttackAdvanceSystem = require(script.Parent.Infrastructure.Systems.Attack.AttackAdvanceSystem)
local CombatRequestCleanupSystem = require(script.Parent.Infrastructure.Systems.Attack.CombatRequestCleanupSystem)
local DamageResolveSystem = require(script.Parent.Infrastructure.Systems.Attack.DamageResolveSystem)
local BaseDamageResolveSystem = require(script.Parent.Infrastructure.Systems.Attack.BaseDamageResolveSystem)
local HealthDepletedOutcomeSystem = require(script.Parent.Infrastructure.Systems.Outcome.HealthDepletedOutcomeSystem)
local HitboxImpactSystem = require(script.Parent.Infrastructure.Systems.Attack.HitboxImpactSystem)
local HitboxSpawnSystem = require(script.Parent.Infrastructure.Systems.Attack.HitboxSpawnSystem)
local ProjectileImpactSystem = require(script.Parent.Infrastructure.Systems.Attack.ProjectileImpactSystem)
local ProjectileSpawnSystem = require(script.Parent.Infrastructure.Systems.Attack.ProjectileSpawnSystem)
local MovementApplySystem = require(script.Parent.Infrastructure.Systems.Movement.MovementApplySystem)
local MovementEntitySchema = require(script.Parent.Infrastructure.Entity.MovementEntitySchema)
local MovementCleanupOutcomeSystem = require(script.Parent.Infrastructure.Systems.Movement.MovementCleanupOutcomeSystem)
local MovementFlowCalculationSystem = require(script.Parent.Infrastructure.Systems.Movement.MovementFlowCalculationSystem)
local MovementGoalReachedSystem = require(script.Parent.Infrastructure.Systems.Movement.MovementGoalReachedSystem)
local MovementGridSystem = require(script.Parent.Infrastructure.Systems.Movement.MovementGridSystem)
local MovementPresentationProjectionSystem = require(script.Parent.Infrastructure.Systems.Movement.MovementPresentationProjectionSystem)


local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "CombatAbilityRegistryService",
		Module = CombatAbilityRegistryService,
		CacheAs = "_combatAbilityRegistryService",
	},
	{
		Name = "CombatOutcomeRuleRegistryService",
		Module = CombatOutcomeRuleRegistryService,
		CacheAs = "_combatOutcomeRuleRegistryService",
	},
	{
		Name = "CombatRequestFactoryService",
		Module = CombatRequestFactoryService,
		CacheAs = "_combatRequestFactoryService",
	},
	{
		Name = "CombatTargetReadService",
		Module = CombatTargetReadService,
		CacheAs = "_combatTargetReadService",
	},
	{
		Name = "LockOnService",
		Module = LockOnService,
		CacheAs = "_lockOnService",
	},
	{
		Name = "MovementActorReadService",
		Module = MovementActorReadService,
		CacheAs = "_movementActorReadService",
	},
	{
		Name = "MovementActorSetupService",
		Module = MovementActorSetupService,
		CacheAs = "_movementActorSetupService",
	},
	{
		Name = "MovementApplyBridgeService",
		Module = MovementApplyBridgeService,
		CacheAs = "_movementApplyBridgeService",
	},
	{
		Name = "MovementFlowDispatchService",
		Module = MovementFlowDispatchService,
		CacheAs = "_movementFlowDispatchService",
	},
	{
		Name = "MovementFlowSnapshotService",
		Module = MovementFlowSnapshotService,
		CacheAs = "_movementFlowSnapshotService",
	},
	{
		Name = "MovementFlowfieldService",
		Module = MovementFlowfieldService,
		CacheAs = "_movementFlowfieldService",
	},
	{
		Name = "MovementGridService",
		Module = MovementGridService,
		CacheAs = "_movementGridService",
	},
	{
		Name = "MovementPathRuntimeService",
		Module = MovementPathRuntimeService,
		CacheAs = "_movementPathRuntimeService",
	},
	{
		Name = "ProjectileSimulationService",
		Module = ProjectileSimulationService,
		CacheAs = "_projectileSimulationService",
	},
	{
		Name = "HitboxSimulationService",
		Module = HitboxSimulationService,
		CacheAs = "_hitboxSimulationService",
	},
	{
		Name = "StatusService",
		Module = StatusService,
		CacheAs = "_statusService",
	},
}

local CombatModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
}

local CombatContext = Knit.CreateService({
	Name = "CombatContext",
	Client = {},
	Modules = CombatModules,
	StartOrder = { "Infrastructure", "Application" },
	ExternalServices = {
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "BaseContext", CacheAs = "_baseContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runStartedConnection", Method = "Disconnect" },
			{ Field = "_runWaveStartedConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
			{ Field = "_movementApplyBridgeService", Method = "CleanupAll" },
			{ Field = "_movementPathRuntimeService", Method = "CleanupAll" },
			{ Field = "_movementFlowSnapshotService", Method = "Destroy" },
			{ Field = "_movementFlowDispatchService", Method = "Destroy" },
			{ Field = "_projectileSimulationService", Method = "Destroy" },
			{ Field = "_hitboxSimulationService", Method = "Destroy" },
		},
	},
})

local CombatBaseContext = BaseContext.new(CombatContext)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

local schedulerProfilingEnabled = DebugConfig.COMBAT_SCHEDULER_PROFILING
local combatTickProfileTag = "Combat.Scheduler.CombatTick"
local combatHitboxTickProfileTag = "Combat.Scheduler.CombatTick.HitboxTick"

function CombatContext:KnitInit()
	CombatBaseContext:KnitInit()

	self._runStartedConnection = nil :: any
	self._runWaveStartedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
end

function CombatContext:KnitStart()
	CombatBaseContext:KnitStart()
	self._movementPathRuntimeService:Configure(self._movementActorReadService, self._entityContext)
	self._movementFlowfieldService:Configure(self._movementGridService)
	self._movementFlowSnapshotService:Configure(self._movementGridService)
	self._movementApplyBridgeService:Configure(self._movementActorReadService, self._entityContext, self._lockOnService)
	self._movementFlowDispatchService:Prime()
	self._statusService:ConfigureEntityContext(self._entityContext)

	local entityRegistrationResult = self:_RegisterEntityActionPipeline()
	if not entityRegistrationResult.success then
		error(("CombatContext failed to register Entity action pipeline: [%s] %s"):format(
			tostring(entityRegistrationResult.type),
			tostring(entityRegistrationResult.message)
		))
	end

	CombatBaseContext:RegisterSchedulerSystem("CombatTick", function()
		DebugPlus.profile(combatTickProfileTag, function()
			local dt = CombatBaseContext:GetSchedulerDeltaTime()

			DebugPlus.profile(combatHitboxTickProfileTag, function()
				self._hitboxSimulationService:Tick(dt)
			end, schedulerProfilingEnabled)

		end, schedulerProfilingEnabled)
	end)

	CombatBaseContext:OnContextEvent("Run", "RunStarted", function()
		self:_OnRunStarted()
	end, "_runStartedConnection")

	CombatBaseContext:OnContextEvent("Run", "WaveStarted", function(waveNumber: number, isEndless: boolean)
		self:_OnRunWaveStarted(waveNumber, isEndless)
	end, "_runWaveStartedConnection")

	CombatBaseContext:OnContextEvent("Run", "RunEnded", function()
		self:_OnRunEnded()
	end, "_runEndedConnection")

	CombatBaseContext:OnPlayerRemoving(function(player: Player)
		self:_OnPlayerRemoving(player)
	end, "_playerRemovingConnection")

end

function CombatContext:_RegisterEntityActionPipeline(): Result.Result<boolean>
	return Catch(function()
		local abilityResult = self._combatAbilityRegistryService:SeedAbilities(CombatAbilities)
		if not abilityResult.success then
			return abilityResult
		end

		local schemaResult = self._entityContext:RegisterFeatureSchema("Combat", CombatEntitySchema)
		if not schemaResult.success then
			return schemaResult
		end

		local movementSchemaResult = self._entityContext:RegisterFeatureSchema("Movement", MovementEntitySchema)
		if not movementSchemaResult.success then
			return movementSchemaResult
		end

		local movementCleanupResult = self._entityContext:RegisterSystem("CleanupResolve", {
			Name = "MovementCleanupOutcomeSystem",
			Phase = "CleanupResolve",
			Reads = {
				"Entity.CleanupOutcomeRequest",
				"Entity.CleanupRequestTag",
			},
			Writes = {
				"Entity.CleanupOutcomeRequest",
				"Entity.CleanupProcessedTag",
				"Entity.CleanupFailedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return MovementCleanupOutcomeSystem.new(entityFactory, {
					PathRuntimeService = self._movementPathRuntimeService,
					FlowfieldService = self._movementFlowfieldService,
					ApplyBridgeService = self._movementApplyBridgeService,
				})
			end,
		})
		if not movementCleanupResult.success then
			return movementCleanupResult
		end

		local movementGridResult = self._entityContext:RegisterSystem("MovementGrid", {
			Name = "MovementGridSystem",
			Phase = "MovementGrid",
			Reads = {
				"Movement.MoveIntent",
			},
			Writes = {
				"Movement.FlowGridState",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return MovementGridSystem.new(entityFactory, {
					MovementGridService = self._movementGridService,
					WorldContext = self._worldContext,
				})
			end,
		})
		if not movementGridResult.success then
			return movementGridResult
		end

		local movementCalculationResult = self._entityContext:RegisterSystem("MovementCalculate", {
			Name = "MovementFlowCalculationSystem",
			Phase = "MovementCalculate",
			Reads = {
				"Movement.MoveIntent",
				"Movement.FlowGridState",
			},
			Writes = {
				"Movement.PathRuntimeState",
				"Movement.FlowCalculationState",
				"Movement.ApplyState",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return MovementFlowCalculationSystem.new(entityFactory, {
					ActorReadService = self._movementActorReadService,
					FlowfieldService = self._movementFlowfieldService,
					FlowDispatchService = self._movementFlowDispatchService,
					FlowSnapshotService = self._movementFlowSnapshotService,
					PathRuntimeService = self._movementPathRuntimeService,
					EntityContext = self._entityContext,
				})
			end,
		})
		if not movementCalculationResult.success then
			return movementCalculationResult
		end

		local movementApplyResult = self._entityContext:RegisterSystem("MovementApply", {
			Name = "MovementApplySystem",
			Phase = "MovementApply",
			Reads = {
				"Movement.ApplyState",
			},
			Writes = {
				"Movement.ApplyResult",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return MovementApplySystem.new(entityFactory, {
					ApplyBridgeService = self._movementApplyBridgeService,
				})
			end,
		})
		if not movementApplyResult.success then
			return movementApplyResult
		end

		local movementPresentationResult = self._entityContext:RegisterSystem("Execute", {
			Name = "MovementPresentationProjectionSystem",
			Phase = "Execute",
			Reads = {
				"Movement.MoveIntent",
				"Movement.ApplyResult",
				"Movement.SpeedState",
				"Combat.AttackState",
				"AI.ActionState",
			},
			Writes = {
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return MovementPresentationProjectionSystem.new(entityFactory, self._combatOutcomeRuleRegistryService)
			end,
		})
		if not movementPresentationResult.success then
			return movementPresentationResult
		end

		local movementGoalReachedResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "MovementGoalReachedSystem",
			Phase = "RequestResolve",
			Reads = {
				"Movement.MoveIntent",
				"Movement.ApplyResult",
			},
			Writes = {
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return MovementGoalReachedSystem.new(entityFactory, self._combatOutcomeRuleRegistryService)
			end,
		})
		if not movementGoalReachedResult.success then
			return movementGoalReachedResult
		end

		self._combatTargetReadService:Configure(self._entityContext)

		local attackResult = self._entityContext:RegisterSystem("ActionAdvance", {
			Name = "AttackAdvanceSystem",
			Phase = "ActionAdvance",
			Reads = {
				"Combat.AttackState",
			},
			Writes = {
				"Combat.AttackState",
				"Combat.DamageRequest",
				"Combat.HitboxSpawnRequest",
				"Combat.ProjectileSpawnRequest",
				"Combat.RequestTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return AttackAdvanceSystem.new(entityFactory, {
					AbilityRegistry = self._combatAbilityRegistryService,
					RequestFactory = self._combatRequestFactoryService,
				})
			end,
		})
		if not attackResult.success then
			return attackResult
		end

		local hitboxSpawnResult = self._entityContext:RegisterSystem("MechanicSpawn", {
			Name = "HitboxSpawnSystem",
			Phase = "MechanicSpawn",
			Reads = {
				"Combat.HitboxSpawnRequest",
				"Combat.RequestTag",
			},
			Writes = {
				"Combat.ActiveHitboxState",
				"Combat.ActiveProjectileState",
				"Combat.ProcessedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return HitboxSpawnSystem.new(entityFactory, {
					Simulation = self._hitboxSimulationService,
					TargetRead = self._combatTargetReadService,
				})
			end,
		})
		if not hitboxSpawnResult.success then
			return hitboxSpawnResult
		end

		local projectileSpawnResult = self._entityContext:RegisterSystem("MechanicSpawn", {
			Name = "ProjectileSpawnSystem",
			Phase = "MechanicSpawn",
			Reads = {
				"Combat.ProjectileSpawnRequest",
				"Combat.RequestTag",
			},
			Writes = {
				"Combat.ActiveProjectileState",
				"Combat.ProcessedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return ProjectileSpawnSystem.new(entityFactory, {
					Simulation = self._projectileSimulationService,
					TargetRead = self._combatTargetReadService,
				})
			end,
		})
		if not projectileSpawnResult.success then
			return projectileSpawnResult
		end

		local hitboxImpactResult = self._entityContext:RegisterSystem("MechanicImpact", {
			Name = "HitboxImpactSystem",
			Phase = "MechanicImpact",
			Writes = {
				"Combat.DamageRequest",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return HitboxImpactSystem.new(entityFactory, {
					Simulation = self._hitboxSimulationService,
					RequestFactory = self._combatRequestFactoryService,
				})
			end,
		})
		if not hitboxImpactResult.success then
			return hitboxImpactResult
		end

		local projectileImpactResult = self._entityContext:RegisterSystem("MechanicImpact", {
			Name = "ProjectileImpactSystem",
			Phase = "MechanicImpact",
			Writes = {
				"Combat.DamageRequest",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return ProjectileImpactSystem.new(entityFactory, {
					Simulation = self._projectileSimulationService,
					RequestFactory = self._combatRequestFactoryService,
				})
			end,
		})
		if not projectileImpactResult.success then
			return projectileImpactResult
		end

		local statusResult = self._entityContext:RegisterSystem("ActionAdvance", {
			Name = "CombatStatusAuraSystem",
			Phase = "ActionAdvance",
			Reads = {
				"Combat.StatusAuraState",
				"Structure.Stats",
				"Entity.Transform",
				"Entity.Identity",
				"AI.ActionState",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return CombatStatusAuraSystem.new(entityFactory, self._statusService)
			end,
		})
		if not statusResult.success then
			return statusResult
		end

		local speedStatusResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "MovementSpeedStatusSystem",
			Phase = "RequestResolve",
			Factory = function(_entityFactory: any, _compiledSchemas: any)
				return MovementSpeedStatusSystem.new(self._statusService)
			end,
		})
		if not speedStatusResult.success then return speedStatusResult end

		local damageResult = self._entityContext:RegisterSystem("DamageResolve", {
			Name = "DamageResolveSystem",
			Phase = "DamageResolve",
			Reads = {
				"Combat.DamageRequest",
				"Combat.RequestTag",
				"Entity.Health",
			},
			Writes = {
				"Entity.Health",
				"Entity.DirtyTag",
				"Combat.ProcessedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return DamageResolveSystem.new(entityFactory, self._combatRequestFactoryService)
			end,
		})
		if not damageResult.success then
			return damageResult
		end

		local baseDamageResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "BaseDamageResolveSystem",
			Phase = "RequestResolve",
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return BaseDamageResolveSystem.new(entityFactory, self._baseContext)
			end,
		})
		if not baseDamageResult.success then
			return baseDamageResult
		end

		local healthDepletedResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "HealthDepletedOutcomeSystem",
			Phase = "RequestResolve",
			Reads = {
				"Combat.HealthDepletedRequest",
				"Combat.RequestTag",
			},
			Writes = {
				"Combat.ProcessedTag",
				"Entity.DestructionQueue",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return HealthDepletedOutcomeSystem.new(entityFactory, {
					EntityContext = self._entityContext,
					RuleRegistry = self._combatOutcomeRuleRegistryService,
				})
			end,
		})
		if not healthDepletedResult.success then
			return healthDepletedResult
		end

		return self._entityContext:RegisterSystem("Cleanup", {
			Name = "CombatRequestCleanupSystem",
			Phase = "Cleanup",
			Reads = {
				"Combat.RequestTag",
				"Combat.ProcessedTag",
				"Combat.HitboxSpawnRequest",
				"Combat.DamageRequest",
				"Combat.HealthDepletedRequest",
				"Combat.GoalReachedOutcomeRequest",
				"Combat.BaseDamageRequest",
				"Combat.ProjectileSpawnRequest",
				"Combat.ActiveHitboxState",
			},
			Writes = {
				"Entity.DestructionQueue",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return CombatRequestCleanupSystem.new(entityFactory, {
					HitboxSimulation = self._hitboxSimulationService,
					ProjectileSimulation = self._projectileSimulationService,
				})
			end,
		})
	end, "Combat:RegisterEntityActionPipeline")
end

function CombatContext:_OnRunStarted()
	self:WarmMovementRuntime()
end

function CombatContext:_OnRunWaveStarted(_waveNumber: number, _isEndless: boolean) end

function CombatContext:_OnRunEnded()
	self._statusService:ClearAll()
	self._movementPathRuntimeService:CleanupAll()
	self._movementFlowfieldService:Reset()
	self._projectileSimulationService:CleanupAll()
	self._hitboxSimulationService:CleanupAll()
end

function CombatContext:_OnPlayerRemoving(_player: Player)
	return
end

function CombatContext:SetupMovementActor(entity: number, profile: any): Result.Result<boolean>
	return self._movementActorSetupService:Setup(self._entityContext, entity, profile)
end

function CombatContext:RequestDamage(payload: any): Result.Result<boolean>
	return Catch(function()
		local request = table.clone(payload)
		request.CreatedAt = if type(request.CreatedAt) == "number" then request.CreatedAt else os.clock()
		local result = self._entityContext:CreateEntity("Combat.DamageRequest", {
			DamageRequest = request,
		})
		Try(result)
		return Ok(true)
	end, "Combat:RequestDamage")
end

function CombatContext:RegisterMovementPresentationRule(payload: any): Result.Result<boolean>
	return Catch(function()
		return Ok(self._combatOutcomeRuleRegistryService:RegisterMovementPresentationRule(payload))
	end, "Combat:RegisterMovementPresentationRule")
end

function CombatContext:RegisterHealthDepletedRule(payload: any): Result.Result<boolean>
	return Catch(function()
		return Ok(self._combatOutcomeRuleRegistryService:RegisterHealthDepletedRule(payload))
	end, "Combat:RegisterHealthDepletedRule")
end

function CombatContext:RegisterMovementGoalReachedRule(payload: any): Result.Result<boolean>
	return Catch(function()
		return Ok(self._combatOutcomeRuleRegistryService:RegisterGoalReachedRule(payload))
	end, "Combat:RegisterMovementGoalReachedRule")
end

function CombatContext:WarmMovementRuntime(): Result.Result<boolean>
	self._movementGridService:Reset()
	self._movementFlowfieldService:Reset()
	self._movementFlowSnapshotService:Reset()
	self._movementFlowDispatchService:Reset()
	self._movementFlowDispatchService:Prime()
	return Ok(true)
end

function CombatContext:_BeforeDestroy()
	self:_OnRunEnded()
end

function CombatContext:Destroy()
	local destroyResult = CombatBaseContext:Destroy()
	if not destroyResult.success then
		Result.MentionError("Combat:Destroy", "BaseContext teardown failed", {
			CauseType = destroyResult.type,
			CauseMessage = destroyResult.message,
		}, destroyResult.type)
	end
end

return CombatContext
