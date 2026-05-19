--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DebugConfig = require(ReplicatedStorage.Config.DebugConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local DebugPlus = require(ReplicatedStorage.Utilities.DebugPlus)
local Result = require(ReplicatedStorage.Utilities.Result)
local CombatTypes = require(ReplicatedStorage.Contexts.Combat.Types.CombatTypes)

local CombatActorRegistryService = require(script.Parent.Infrastructure.Services.CombatActorRegistryService)
local CombatLoopService = require(script.Parent.Infrastructure.Services.CombatLoopService)
local CombatBehaviorRuntimeService = require(script.Parent.Infrastructure.Services.CombatBehaviorRuntimeService)
local CombatHitResolutionService = require(script.Parent.Infrastructure.Services.CombatHitResolutionService)
local HitboxService = require(script.Parent.Infrastructure.Services.HitboxService)
local LockOnService = require(script.Parent.Infrastructure.Services.LockOnService)
local MovementService = require(script.Parent.Infrastructure.Services.MovementService)
local ProjectileService = require(script.Parent.Infrastructure.Services.ProjectileService)
local StatusService = require(script.Parent.Infrastructure.Services.StatusService)

local StartCombat = require(script.Parent.Application.Commands.StartCombat)
local ProcessCombatTick = require(script.Parent.Application.Commands.ProcessCombatTick)
local EndCombat = require(script.Parent.Application.Commands.EndCombat)
local HandleAnimationCallback = require(script.Parent.Application.Commands.HandleAnimationCallback)
local RegisterActorTypeCommand = require(script.Parent.Application.Commands.RegisterActorTypeCommand)
local RegisterCombatActorCommand = require(script.Parent.Application.Commands.RegisterCombatActorCommand)
local UnregisterCombatActorCommand = require(script.Parent.Application.Commands.UnregisterCombatActorCommand)
local NotifyActorRemovedCommand = require(script.Parent.Application.Commands.NotifyActorRemovedCommand)

type CombatActorTypePayload = CombatTypes.CombatActorTypePayload
type CombatActorPayload = CombatTypes.CombatActorPayload
type CombatActionState = CombatTypes.CombatActionState

local InfrastructureModules: { BaseContext.TModuleSpec } = {
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
	AIRuntimeContext = {
		RuntimeServiceField = "_combatBehaviorRuntimeService",
		ActorRegistryServiceField = "_combatActorRegistryService",
	},
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runWaveStartedConnection", Method = "Disconnect" },
			{ Field = "_runWaveEndedConnection", Method = "Disconnect" },
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

	self._runWaveStartedConnection = nil :: any
	self._runWaveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
	self._animationCallbackConnection = nil :: any
end

function CombatContext:KnitStart()
	CombatBaseContext:KnitStart()

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

	CombatBaseContext:OnContextEvent("Run", "WaveStarted", function(waveNumber: number, isEndless: boolean)
		self:_OnRunWaveStarted(waveNumber, isEndless)
	end, "_runWaveStartedConnection")

	CombatBaseContext:OnContextEvent("Run", "WaveEnded", function(_waveNumber: number)
		self:_OnRunWaveEnded()
	end, "_runWaveEndedConnection")

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

function CombatContext:_OnRunWaveStarted(waveNumber: number, isEndless: boolean)
	Catch(function()
		Result.MentionEvent("Combat:OnRunWaveStarted", "Received run wave start", {
			WaveNumber = waveNumber,
			IsEndless = isEndless,
			RuntimeStarted = self._combatActorRegistryService:IsRuntimeStarted(),
			ActorTypeCount = #self._combatActorRegistryService:GetActorTypePayloads(),
		})
		Try(self._startCombatCommand:Execute(waveNumber, isEndless))
		return Ok(nil)
	end, "Combat:OnRunWaveStarted")
end

function CombatContext:_OnRunEnded()
	Catch(function()
		Try(self._endCombatCommand:Execute())
		return Ok(nil)
	end, "Combat:OnRunEnded")
end

function CombatContext:_OnRunWaveEnded()
	Catch(function()
		Try(self._endCombatCommand:Execute())
		return Ok(nil)
	end, "Combat:OnRunWaveEnded")
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
