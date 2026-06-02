--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ServerStorage.Utilities.ContextUtilities.BaseContext)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

local CombatAbilities = require(script.Parent.Config.CombatAbilities)
local CombatActorRegistryService = require(script.Parent.Infrastructure.Services.CombatActorRegistryService)
local CombatAbilityRegistryService = require(script.Parent.Infrastructure.Services.CombatAbilityRegistryService)
local CombatRequestFactoryService = require(script.Parent.Infrastructure.Services.CombatRequestFactoryService)
local CombatTargetReadService = require(script.Parent.Infrastructure.Services.CombatTargetReadService)
local CombatLoopService = require(script.Parent.Infrastructure.Services.CombatLoopService)
local CombatBehaviorRuntimeService = require(script.Parent.Infrastructure.Services.CombatBehaviorRuntimeService)
local CombatHitResolutionService = require(script.Parent.Infrastructure.Services.CombatHitResolutionService)
local HitboxService = require(script.Parent.Infrastructure.Services.HitboxService)
local LockOnService = require(script.Parent.Infrastructure.Services.LockOnService)
local MovementActorReadService = require(script.Parent.Infrastructure.Services.Movement.MovementActorReadService)
local MovementApplyBridgeService = require(script.Parent.Infrastructure.Services.Movement.MovementApplyBridgeService)
local MovementFlowDispatchService = require(script.Parent.Infrastructure.Services.Movement.MovementFlowDispatchService)
local MovementFlowSnapshotService = require(script.Parent.Infrastructure.Services.Movement.MovementFlowSnapshotService)
local MovementFlowfieldService = require(script.Parent.Infrastructure.Services.Movement.MovementFlowfieldService)
local MovementGridService = require(script.Parent.Infrastructure.Services.Movement.MovementGridService)
local MovementPathRuntimeService = require(script.Parent.Infrastructure.Services.Movement.MovementPathRuntimeService)
local ProjectileService = require(script.Parent.Infrastructure.Services.ProjectileService)
local ProjectileSimulationService = require(script.Parent.Infrastructure.Services.ProjectileSimulationService)
local StatusService = require(script.Parent.Infrastructure.Services.StatusService)
local CombatEntitySchema = require(script.Parent.Infrastructure.Entity.CombatEntitySchema)
local CombatStatusAuraSystem = require(script.Parent.Infrastructure.Entity.CombatStatusAuraSystem)
local HitboxSimulationService = require(script.Parent.Infrastructure.Services.HitboxSimulationService)
local AttackAdvanceSystem = require(script.Parent.Infrastructure.Systems.Attack.AttackAdvanceSystem)
local CombatRequestCleanupSystem = require(script.Parent.Infrastructure.Systems.Attack.CombatRequestCleanupSystem)
local DamageResolveSystem = require(script.Parent.Infrastructure.Systems.Attack.DamageResolveSystem)
local HitboxImpactSystem = require(script.Parent.Infrastructure.Systems.Attack.HitboxImpactSystem)
local HitboxSpawnSystem = require(script.Parent.Infrastructure.Systems.Attack.HitboxSpawnSystem)
local ProjectileImpactSystem = require(script.Parent.Infrastructure.Systems.Attack.ProjectileImpactSystem)
local ProjectileSpawnSystem = require(script.Parent.Infrastructure.Systems.Attack.ProjectileSpawnSystem)
local MovementApplySystem = require(script.Parent.Infrastructure.Systems.MovementApplySystem)
local MovementEntitySchema = require(script.Parent.Infrastructure.Systems.MovementEntitySchema)
local MovementFlowCalculationSystem = require(script.Parent.Infrastructure.Systems.MovementFlowCalculationSystem)
local MovementGridSystem = require(script.Parent.Infrastructure.Systems.MovementGridSystem)

local StartCombat = require(script.Parent.Application.Commands.StartCombat)
local ProcessCombatTick = require(script.Parent.Application.Commands.ProcessCombatTick)
local EndCombat = require(script.Parent.Application.Commands.EndCombat)
local HandleAnimationCallback = require(script.Parent.Application.Commands.HandleAnimationCallback)
local RegisterActorTypeCommand = require(script.Parent.Application.Commands.RegisterActorTypeCommand)
local RegisterCombatActorCommand = require(script.Parent.Application.Commands.RegisterCombatActorCommand)
local UnregisterCombatActorCommand = require(script.Parent.Application.Commands.UnregisterCombatActorCommand)
local NotifyActorRemovedCommand = require(script.Parent.Application.Commands.NotifyActorRemovedCommand)
local UpdateCombatWaveContextCommand = require(script.Parent.Application.Commands.UpdateCombatWaveContextCommand)

type CombatActorTypePayload = CombatTypes.CombatActorTypePayload
type CombatActorPayload = CombatTypes.CombatActorPayload
type CombatActionState = CombatTypes.CombatActionState

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "CombatAbilityRegistryService",
		Module = CombatAbilityRegistryService,
		CacheAs = "_combatAbilityRegistryService",
	},
	{
		Name = "CombatActorRegistryService",
		Module = CombatActorRegistryService,
		CacheAs = "_combatActorRegistryService",
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
		Name = "CombatLoopService",
		Module = CombatLoopService,
		CacheAs = "_combatLoopService",
	},
	{
		Name = "CombatBehaviorRuntimeService",
		Module = CombatBehaviorRuntimeService,
		CacheAs = "_combatBehaviorRuntimeService",
	},
	{
		Name = "CombatHitResolutionService",
		Module = CombatHitResolutionService,
		CacheAs = "_combatHitResolutionService",
	},
	{
		Name = "HitboxService",
		Module = HitboxService,
		CacheAs = "_hitboxService",
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
		Name = "ProjectileService",
		Module = ProjectileService,
		CacheAs = "_projectileService",
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

local ApplicationModules: { BaseContext.TModuleSpec } = {
	{
		Name = "StartCombat",
		Module = StartCombat,
		CacheAs = "_startCombatCommand",
	},
	{
		Name = "ProcessCombatTick",
		Module = ProcessCombatTick,
		CacheAs = "_processCombatTickCommand",
	},
	{
		Name = "EndCombat",
		Module = EndCombat,
		CacheAs = "_endCombatCommand",
	},
	{
		Name = "HandleAnimationCallback",
		Module = HandleAnimationCallback,
		CacheAs = "_handleAnimationCallbackCommand",
	},
	{
		Name = "RegisterActorTypeCommand",
		Module = RegisterActorTypeCommand,
		CacheAs = "_registerActorTypeCommand",
	},
	{
		Name = "RegisterCombatActorCommand",
		Module = RegisterCombatActorCommand,
		CacheAs = "_registerCombatActorCommand",
	},
	{
		Name = "UnregisterCombatActorCommand",
		Module = UnregisterCombatActorCommand,
		CacheAs = "_unregisterCombatActorCommand",
	},
	{
		Name = "UpdateCombatWaveContextCommand",
		Module = UpdateCombatWaveContextCommand,
		CacheAs = "_updateCombatWaveContextCommand",
	},
	{
		Name = "NotifyActorRemovedCommand",
		Module = NotifyActorRemovedCommand,
		CacheAs = "_notifyActorRemovedCommand",
	},
}

local CombatModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Application = ApplicationModules,
}

local CombatContext = Knit.CreateService({
	Name = "CombatContext",
	Client = {
		AnimationCallback = Knit.CreateSignal(),
	},
	Modules = CombatModules,
	StartOrder = { "Infrastructure", "Application" },
	ExternalServices = {
		{ Name = "EntityContext", CacheAs = "_entityContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
	},
	AIRuntimeContext = {
		RuntimeServiceField = "_combatBehaviorRuntimeService",
		ActorRegistryServiceField = "_combatActorRegistryService",
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runStartedConnection", Method = "Disconnect" },
			{ Field = "_runWaveStartedConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
			{ Field = "_animationCallbackConnection", Method = "Disconnect" },
			{ Field = "_movementApplyBridgeService", Method = "CleanupAll" },
			{ Field = "_movementPathRuntimeService", Method = "CleanupAll" },
			{ Field = "_movementFlowSnapshotService", Method = "Destroy" },
			{ Field = "_movementFlowDispatchService", Method = "Destroy" },
			{ Field = "_projectileService", Method = "Destroy" },
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
local combatProcessSessionsProfileTag = "Combat.Scheduler.CombatTick.ProcessSessions"
local combatEvaluateEnemyMoveSpeedEffectsProfileTag = "Combat.Scheduler.CombatTick.EvaluateEnemyMoveSpeedEffects"

function CombatContext:KnitInit()
	CombatBaseContext:KnitInit()

	self._runStartedConnection = nil :: any
	self._runWaveStartedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
	self._animationCallbackConnection = nil :: any
end

function CombatContext:KnitStart()
	CombatBaseContext:KnitStart()
	self._movementPathRuntimeService:Configure(self._movementActorReadService, self._entityContext)
	self._movementFlowfieldService:Configure(self._movementGridService)
	self._movementFlowSnapshotService:Configure(self._movementGridService)
	self._movementApplyBridgeService:Configure(self._movementActorReadService, self._entityContext, self._lockOnService)
	self._movementFlowDispatchService:Prime()

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
				self._hitboxService:Tick(dt)
				self._hitboxSimulationService:Tick(dt)
			end, schedulerProfilingEnabled)

			local didRunCombatFrame = false
			local schedulerTickId = self._combatLoopService:AdvanceTickId()
			DebugPlus.profile(combatProcessSessionsProfileTag, function()
				self._combatLoopService:ForEachSession(function(userId: number)
					local tickResult = self._processCombatTickCommand:Execute(userId, dt, schedulerTickId)
					if tickResult.success and tickResult.value then
						didRunCombatFrame = true
					end
					return nil
				end)
			end, schedulerProfilingEnabled)

			if didRunCombatFrame then
				-- Enemy move speed is derived from shared live combat state, so refresh it once per frame.
				DebugPlus.profile(combatEvaluateEnemyMoveSpeedEffectsProfileTag, function()
					self._statusService:EvaluateEnemyMoveSpeedEffects()
				end, schedulerProfilingEnabled)
			end

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

	self._animationCallbackConnection = self.Client.AnimationCallback:Connect(
		function(player: Player, actorHandle: string, callbackType: string, actorKind: "Enemy" | "Structure"?)
			self._handleAnimationCallbackCommand:Execute(player, actorHandle, callbackType, actorKind)
		end
	)
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
			Writes = {
				"Structure.AnimationState",
				"Structure.AnimationLooping",
				"Structure.TargetEnemyId",
				"Entity.DirtyTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return CombatStatusAuraSystem.new(entityFactory, self._statusService)
			end,
		})
		if not statusResult.success then
			return statusResult
		end

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
				return DamageResolveSystem.new(entityFactory)
			end,
		})
		if not damageResult.success then
			return damageResult
		end

		return self._entityContext:RegisterSystem("Cleanup", {
			Name = "CombatRequestCleanupSystem",
			Phase = "Cleanup",
			Reads = {
				"Combat.RequestTag",
				"Combat.ProcessedTag",
				"Combat.HitboxSpawnRequest",
				"Combat.DamageRequest",
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
	Catch(function()
		Result.MentionEvent("Combat:OnRunStarted", "Received run start", {
			RuntimeStarted = self._combatActorRegistryService:IsRuntimeStarted(),
			ActorTypeCount = #self._combatActorRegistryService:GetActorTypePayloads(),
		})
		Try(self._startCombatCommand:Execute())
		return Ok(nil)
	end, "Combat:OnRunStarted")
end

function CombatContext:_OnRunWaveStarted(waveNumber: number, isEndless: boolean)
	Catch(function()
		local primaryPlayer = Players:GetPlayers()[1]
		if primaryPlayer == nil then
			return Ok(nil)
		end

		Result.MentionEvent("Combat:OnRunWaveStarted", "Received run wave start", {
			WaveNumber = waveNumber,
			IsEndless = isEndless,
			PrimaryPlayerUserId = primaryPlayer.UserId,
		})
		Try(self._updateCombatWaveContextCommand:Execute(primaryPlayer.UserId, waveNumber, isEndless))
		return Ok(nil)
	end, "Combat:OnRunWaveStarted")
end

function CombatContext:_OnRunEnded()
	Catch(function()
		Try(self._endCombatCommand:Execute())
		return Ok(nil)
	end, "Combat:OnRunEnded")
end

function CombatContext:_OnPlayerRemoving(_player: Player)
	if #Players:GetPlayers() <= 1 then
		self:_OnRunEnded()
	end
end

function CombatContext:GetCombatLoopService(): Result.Result<any>
	return Ok(self._combatLoopService)
end

function CombatContext:GetCombatRuntimeServices(): Result.Result<any>
	return Ok({
		HitboxService = self._hitboxService,
		LockOnService = self._lockOnService,
		CombatHitResolutionService = self._combatHitResolutionService,
		ProjectileService = self._projectileService,
		StatusService = self._statusService,
	})
end

function CombatContext:GetCombatActorActionState(actorHandle: string): Result.Result<CombatActionState?>
	return Ok(self._combatActorRegistryService:GetActionStateByHandle(actorHandle))
end

function CombatContext:RegisterActorType(payload: CombatActorTypePayload): Result.Result<boolean>
	return Catch(function()
		return self._registerActorTypeCommand:Execute(payload)
	end, "Combat:RegisterActorType")
end

function CombatContext:RegisterCombatActor(payload: CombatActorPayload): Result.Result<string>
	return Catch(function()
		return self._registerCombatActorCommand:Execute(payload)
	end, "Combat:RegisterCombatActor")
end

function CombatContext:UnregisterCombatActor(actorHandle: string): Result.Result<boolean>
	return Catch(function()
		return self._unregisterCombatActorCommand:Execute(actorHandle)
	end, "Combat:UnregisterCombatActor")
end

function CombatContext:NotifyActorRemoved(actorHandle: string): Result.Result<boolean>
	return Catch(function()
		return self._notifyActorRemovedCommand:Execute(actorHandle)
	end, "Combat:NotifyActorRemoved")
end

function CombatContext:_BeforeDestroy()
	Catch(function()
		if self._endCombatCommand then
			Try(self._endCombatCommand:Execute())
		end
		return Ok(nil)
	end, "Combat:Destroy")
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
