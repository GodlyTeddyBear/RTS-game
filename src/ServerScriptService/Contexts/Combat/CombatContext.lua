--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local CombatLoopService = require(script.Parent.Infrastructure.Services.CombatLoopService)
local CombatBehaviorRuntimeService = require(script.Parent.Infrastructure.Services.CombatBehaviorRuntimeService)
local CombatHitResolutionService = require(script.Parent.Infrastructure.Services.CombatHitResolutionService)
local HitboxService = require(script.Parent.Infrastructure.Services.HitboxService)
local LockOnService = require(script.Parent.Infrastructure.Services.LockOnService)
local MovementService = require(script.Parent.Infrastructure.Services.MovementService)
local ProjectileService = require(script.Parent.Infrastructure.Services.ProjectileService)
local CombatPerceptionService = require(script.Parent.CombatDomain.Services.CombatPerceptionService)

local StartCombat = require(script.Parent.Application.Commands.StartCombat)
local ProcessCombatTick = require(script.Parent.Application.Commands.ProcessCombatTick)
local EndCombat = require(script.Parent.Application.Commands.EndCombat)
local HandleGoalReached = require(script.Parent.Application.Commands.HandleGoalReached)
local HandleAnimationCallback = require(script.Parent.Application.Commands.HandleAnimationCallback)

local InfrastructureModules: { BaseContext.TModuleSpec } = {
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
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "CombatPerceptionService",
		Module = CombatPerceptionService,
		CacheAs = "_combatPerceptionService",
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
		Name = "HandleGoalReached",
		Module = HandleGoalReached,
		CacheAs = "_handleGoalReachedCommand",
	},
	{
		Name = "HandleAnimationCallback",
		Module = HandleAnimationCallback,
		CacheAs = "_handleAnimationCallbackCommand",
	},
}

local CombatModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

--[=[
	@class CombatContext
	Owns combat session orchestration, tick wiring, and lifecycle cleanup for the lane-defense run.
	Flow: resolve dependencies -> start wave/session -> drive combat ticks -> stop and clean up.
	@server
]=]
local CombatContext = Knit.CreateService({
	Name = "CombatContext",
	Client = {
		AnimationCallback = Knit.CreateSignal(),
	},
	Modules = CombatModules,
	ExternalServices = {
		{ Name = "EnemyContext", CacheAs = "_enemyContext" },
		{ Name = "StructureContext", CacheAs = "_structureContext" },
		{ Name = "BaseContext", CacheAs = "_baseContext" },
	},
	ExternalDependencies = {
		{
			Name = "EnemyEntityFactory",
			From = "EnemyContext",
			Method = "GetEntityFactory",
			CacheAs = "_enemyEntityFactory",
		},
		{
			Name = "EnemyGameObjectSyncService",
			From = "EnemyContext",
			Method = "GetGameObjectSyncService",
			CacheAs = "_enemyGameObjectSyncService",
		},
		{
			Name = "EnemyInstanceFactory",
			From = "EnemyContext",
			Method = "GetInstanceFactory",
			CacheAs = "_enemyInstanceFactory",
		},
		{
			Name = "StructureEntityFactory",
			From = "StructureContext",
			Method = "GetEntityFactory",
			CacheAs = "_structureEntityFactory",
		},
		{
			Name = "BaseEntityFactory",
			From = "BaseContext",
			Method = "GetEntityFactory",
			CacheAs = "_baseEntityFactory",
		},
		{
			Name = "World",
			From = "EnemyContext",
			Method = "GetWorld",
			CacheAs = "_enemyWorld",
		},
		{
			Name = "Components",
			From = "EnemyContext",
			Method = "GetComponents",
			CacheAs = "_enemyComponents",
		},
	},
	StartOrder = { "Domain", "Infrastructure", "Application" },
	Teardown = {
		Before = "_BeforeDestroy",
		Fields = {
			{ Field = "_runWaveStartedConnection", Method = "Disconnect" },
			{ Field = "_runWaveEndedConnection", Method = "Disconnect" },
			{ Field = "_runEndedConnection", Method = "Disconnect" },
			{ Field = "_enemySpawnedConnection", Method = "Disconnect" },
			{ Field = "_combatActorRemovingConnection", Method = "Disconnect" },
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
			{ Field = "_animationCallbackConnection", Method = "Disconnect" },
			{ Field = "_projectileService", Method = "Destroy" },
		},
	},
})

local CombatBaseContext = BaseContext.new(CombatContext)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

--[=[
	@within CombatContext
	Registers combat infrastructure, policies, and commands before the rest of the server starts ticking.
]=]
function CombatContext:KnitInit()
	CombatBaseContext:KnitInit()

	self._enemyContext = nil
	self._enemyEntityFactory = nil
	self._enemyGameObjectSyncService = nil
	self._enemyInstanceFactory = nil
	self._enemyWorld = nil
	self._enemyComponents = nil
	self._structureContext = nil
	self._structureEntityFactory = nil
	self._baseContext = nil
	self._baseEntityFactory = nil
	self._combatPerceptionService = nil
	self._goalPosition = nil :: Vector3?

	self._runWaveStartedConnection = nil :: any
	self._runWaveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._enemySpawnedConnection = nil :: any
	self._combatActorRemovingConnection = nil :: any
	self._playerRemovingConnection = nil :: any
	self._animationCallbackConnection = nil :: any
end

--[=[
	@within CombatContext
	Resolves dependent contexts, wires event handlers, and registers the heartbeat systems.
]=]
function CombatContext:KnitStart()
	CombatBaseContext:KnitStart()

	-- Lane movement sync still runs independently from combat AI ticks.
	CombatBaseContext:RegisterPollSystem("_enemyGameObjectSyncService", nil, "EnemyPositionPoll")

	-- Drive BT evaluation and executor updates for every active combat session.
	CombatBaseContext:RegisterSchedulerSystem("CombatTick", function()
		local dt = CombatBaseContext:GetSchedulerDeltaTime()
		local shouldUpdateLockOn = false
		for userId, activeCombat in pairs(self._combatLoopService:GetActiveCombats()) do
			if activeCombat.IsPaused then
				continue
			end

			shouldUpdateLockOn = true
			self._processCombatTickCommand:Execute(userId, dt)
		end

		if shouldUpdateLockOn and self._lockOnService ~= nil then
			self._lockOnService:UpdateAll(self._enemyEntityFactory:QueryAliveEntities())
		end
	end)

	CombatBaseContext:OnContextEvent("Run", "WaveStarted", function(waveNumber: number, isEndless: boolean)
		self:_OnRunWaveStarted(waveNumber, isEndless)
	end, "_runWaveStartedConnection")

	CombatBaseContext:OnContextEvent("Run", "WaveEnded", function(waveNumber: number)
		self:_OnRunWaveEnded(waveNumber)
	end, "_runWaveEndedConnection")

	CombatBaseContext:OnContextEvent("Run", "RunEnded", function()
		self:_OnRunEnded()
	end, "_runEndedConnection")

	CombatBaseContext:OnContextEvent(
		"Wave",
		"EnemySpawned",
		function(entity: number, role: string, waveNumber: number)
			self:_OnEnemySpawned(entity, role, waveNumber)
		end,
		"_enemySpawnedConnection"
	)

	CombatBaseContext:OnContextEvent(
		"Combat",
		"ActorRemoving",
		function(actorKind: string, entity: number)
			self:_OnCombatActorRemoving(actorKind, entity)
		end,
		"_combatActorRemovingConnection"
	)

	CombatBaseContext:OnPlayerRemoving(function(player: Player)
		self:_OnPlayerRemoving(player)
	end, "_playerRemovingConnection")

	self._animationCallbackConnection =
		self.Client.AnimationCallback:Connect(function(
			player: Player,
			actorId: string,
			callbackType: string,
			actorKind: "Enemy" | "Structure"?
		)
			self._handleAnimationCallbackCommand:Execute(player, actorId, callbackType, actorKind)
		end)
end

-- Caches the current goal point used by startup and mid-wave enemy spawns.
function CombatContext:_CacheGoalPosition()
	local baseTargetResult = self._baseContext:GetBaseTargetCFrame()

	assert(
		baseTargetResult.success,
		string.format(
			"CombatContext: goal cache failed reading base target point (%s)",
			tostring(baseTargetResult.message or baseTargetResult.type or "unknown")
		)
	)

	local baseTarget = baseTargetResult.value
	self._goalPosition = baseTarget.Position
end

-- Starts combat for the active run wave and assigns behavior trees to existing enemies.
function CombatContext:_OnRunWaveStarted(waveNumber: number, isEndless: boolean)
	Catch(function()
		self:_CacheGoalPosition()
		self:_AssignGoalPositionToAliveEnemies()
		Try(self._startCombatCommand:Execute(waveNumber, isEndless))
		return Ok(nil)
	end, "Combat:OnRunWaveStarted")
end

-- Stops combat when the run ends so no executors keep running after the lifecycle boundary.
function CombatContext:_OnRunEnded()
	Catch(function()
		Try(self._endCombatCommand:Execute())
		self._goalPosition = nil
		return Ok(nil)
	end, "Combat:OnRunEnded")
end

-- Ends combat cleanup for a wave and clears the enemy context after the last enemy is resolved.
function CombatContext:_OnRunWaveEnded(_waveNumber: number)
	Catch(function()
		Try(self._endCombatCommand:Execute())
		Try(self._enemyContext:CleanupAll())
		self._goalPosition = nil
		return Ok(nil)
	end, "Combat:OnRunWaveEnded")
end

function CombatContext:_AssignGoalPositionToAliveEnemies()
	local goalPosition = self._goalPosition
	if goalPosition == nil then
		return
	end

	for _, entity in ipairs(self._enemyEntityFactory:QueryAliveEntities()) do
		self._enemyEntityFactory:SetGoalPosition(entity, goalPosition)
	end
end

-- Assigns the current goal target to spawned enemies and backfills their behavior tree state if combat is already active.
function CombatContext:_OnEnemySpawned(entity: number, _role: string, _waveNumber: number)
	if self._goalPosition == nil then
		pcall(function()
			self:_CacheGoalPosition()
		end)
	end

	local goalPosition = self._goalPosition
	if goalPosition ~= nil then
		local success, err = pcall(function()
			self._enemyEntityFactory:SetGoalPosition(entity, goalPosition)
		end)
		if not success then
			Result.MentionError("Combat:OnEnemySpawned", "Failed to assign goal position", {
				EnemyEntity = entity,
				CauseMessage = err,
			}, "GoalAssignmentFailed")
			return
		end
	end

	pcall(function()
		self._startCombatCommand:_AssignBehaviorTree(entity)
	end)
end

-- Mirrors the run shutdown path when the last player leaves the server.
function CombatContext:_OnPlayerRemoving(_player: Player)
	if #Players:GetPlayers() <= 1 then
		self:_OnRunEnded()
	end
end

function CombatContext:_OnCombatActorRemoving(actorKind: string, entity: number)
	Catch(function()
		if actorKind ~= "Enemy" and actorKind ~= "Structure" then
			return Ok(nil)
		end

		self._combatBehaviorRuntimeService:HandleActorDeath(actorKind, entity, {
			CurrentTime = os.clock(),
			Services = {
				EnemyEntityFactory = self._enemyEntityFactory,
				StructureEntityFactory = self._structureEntityFactory,
				BaseEntityFactory = self._baseEntityFactory,
				CombatPerceptionService = self._combatPerceptionService,
				EnemyContext = self._enemyContext,
				StructureContext = self._structureContext,
				BaseContext = self._baseContext,
				CurrentTime = os.clock(),
				HandleGoalReached = self._handleGoalReachedCommand,
				HitboxService = self._hitboxService,
				MovementService = self._movementService,
				CombatHitResolutionService = self._combatHitResolutionService,
				ProjectileService = self._projectileService,
			},
		})

		return Ok(nil)
	end, "Combat:OnActorRemoving")
end

--[=[
	@within CombatContext
	Exposes the active combat loop service for other contexts that need to query or control it.
	@return Result.Result<any> -- Active combat loop service or a typed context error.
]=]
function CombatContext:GetCombatLoopService(): Result.Result<any>
	return Ok(self._combatLoopService)
end

function CombatContext:_BeforeDestroy()
	Catch(function()
		if self._endCombatCommand then
			Try(self._endCombatCommand:Execute())
		end
		return Ok(nil)
	end, "Combat:Destroy")
end

--[=[
	@within CombatContext
	Disconnects listeners and stops combat so server shutdown leaves no active tick work behind.
]=]
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
