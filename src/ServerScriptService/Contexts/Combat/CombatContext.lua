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
local CombatLoopService = require(script.Parent.Infrastructure.Services.CombatLoopService)
local CombatBehaviorRuntimeService = require(script.Parent.Infrastructure.Services.CombatBehaviorRuntimeService)
local CombatHitResolutionService = require(script.Parent.Infrastructure.Services.CombatHitResolutionService)
local HitboxService = require(script.Parent.Infrastructure.Services.HitboxService)
local LockOnService = require(script.Parent.Infrastructure.Services.LockOnService)
local MovementService = require(script.Parent.Infrastructure.Services.MovementService)
local ProjectileService = require(script.Parent.Infrastructure.Services.ProjectileService)
local StatusService = require(script.Parent.Infrastructure.Services.StatusService)
local CombatAttackSystem = require(script.Parent.Infrastructure.Entity.CombatAttackSystem)
local CombatDamageSystem = require(script.Parent.Infrastructure.Entity.CombatDamageSystem)
local CombatEntitySchema = require(script.Parent.Infrastructure.Entity.CombatEntitySchema)
local CombatHitboxSystem = require(script.Parent.Infrastructure.Entity.CombatHitboxSystem)
local CombatProjectileSystem = require(script.Parent.Infrastructure.Entity.CombatProjectileSystem)
local CombatRequestCleanupSystem = require(script.Parent.Infrastructure.Entity.CombatRequestCleanupSystem)

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
		Name = "MovementService",
		Module = MovementService,
		CacheAs = "_movementService",
	},
	{
		Name = "ProjectileService",
		Module = ProjectileService,
		CacheAs = "_projectileService",
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
			{ Field = "_movementService", Method = "Destroy" },
			{ Field = "_projectileService", Method = "Destroy" },
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

			self._movementService:FinalizeAdvanceFrame()
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

		local attackResult = self._entityContext:RegisterSystem("ActionAdvance", {
			Name = "CombatAttackSystem",
			Phase = "ActionAdvance",
			Reads = {
				"Combat.AttackState",
			},
			Writes = {
				"Combat.AttackState",
				"Combat.DamageRequest",
				"Combat.RequestTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return CombatAttackSystem.new(entityFactory, self._combatAbilityRegistryService)
			end,
		})
		if not attackResult.success then
			return attackResult
		end

		local hitboxResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "CombatHitboxSystem",
			Phase = "RequestResolve",
			Reads = {
				"Combat.HitboxRequest",
				"Combat.RequestTag",
			},
			Writes = {
				"Combat.DamageRequest",
				"Combat.ProcessedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return CombatHitboxSystem.new(entityFactory)
			end,
		})
		if not hitboxResult.success then
			return hitboxResult
		end

		local projectileResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "CombatProjectileSystem",
			Phase = "RequestResolve",
			Reads = {
				"Combat.ProjectileRequest",
				"Combat.RequestTag",
			},
			Writes = {
				"Combat.ProcessedTag",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return CombatProjectileSystem.new(entityFactory, self._projectileService)
			end,
		})
		if not projectileResult.success then
			return projectileResult
		end

		local damageResult = self._entityContext:RegisterSystem("RequestResolve", {
			Name = "CombatDamageSystem",
			Phase = "RequestResolve",
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
				return CombatDamageSystem.new(entityFactory)
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
				"Combat.HitboxRequest",
				"Combat.DamageRequest",
				"Combat.ProjectileRequest",
			},
			Writes = {
				"Entity.DestructionQueue",
			},
			Factory = function(entityFactory: any, _compiledSchemas: any)
				return CombatRequestCleanupSystem.new(entityFactory)
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
		MovementService = self._movementService,
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
