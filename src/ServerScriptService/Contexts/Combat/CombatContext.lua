--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BaseContext = require(ReplicatedStorage.Utilities.BaseContext)
local Result = require(ReplicatedStorage.Utilities.Result)

local CombatLoopService = require(script.Parent.Infrastructure.Services.CombatLoopService)
local CombatBehaviorRuntimeService = require(script.Parent.Infrastructure.Services.CombatBehaviorRuntimeService)
local WaveCompletionPolicy = require(script.Parent.CombatDomain.Policies.WaveCompletionPolicy)
local CombatPerceptionService = require(script.Parent.CombatDomain.Services.CombatPerceptionService)

local StartCombat = require(script.Parent.Application.Commands.StartCombat)
local ProcessCombatTick = require(script.Parent.Application.Commands.ProcessCombatTick)
local EndCombat = require(script.Parent.Application.Commands.EndCombat)
local HandleGoalReached = require(script.Parent.Application.Commands.HandleGoalReached)

local InfrastructureModules: { BaseContext.TModuleSpec } = {
	{
		Name = "CombatLoopService",
		Module = CombatLoopService,
		CacheAs = "_combatLoopService",
	},
	{
		Name = "CombatBehaviorRuntimeService",
		Module = CombatBehaviorRuntimeService,
	},
}

local DomainModules: { BaseContext.TModuleSpec } = {
	{
		Name = "WaveCompletionPolicy",
		Module = WaveCompletionPolicy,
	},
	{
		Name = "CombatPerceptionService",
		Module = CombatPerceptionService,
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
}

local CombatModules: BaseContext.TModuleLayers = {
	Infrastructure = InfrastructureModules,
	Domain = DomainModules,
	Application = ApplicationModules,
}

--[=[
	@class CombatContext
	Coordinates combat start, tick, cleanup, and enemy goal resolution for the lane-defense run.
	@server
]=]
local CombatContext = Knit.CreateService({
	Name = "CombatContext",
	Client = {},
	Modules = CombatModules,
	ExternalServices = {
		{ Name = "EnemyContext", CacheAs = "_enemyContext" },
		{ Name = "WorldContext", CacheAs = "_worldContext" },
		{ Name = "CommanderContext", CacheAs = "_commanderContext" },
		{ Name = "StructureContext", CacheAs = "_structureContext" },
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
			{ Field = "_playerRemovingConnection", Method = "Disconnect" },
		},
	},
})

local CombatBaseContext = BaseContext.new(CombatContext)

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

-- Sorts lane tiles so the generated waypoint list follows the lane from start to goal.
local function _sortLaneTiles(laneTiles: { any }): { any }
	local cloned = table.clone(laneTiles)
	table.sort(cloned, function(a, b)
		local aCoord = a.coord
		local bCoord = b.coord
		if aCoord.row == bCoord.row then
			return aCoord.col < bCoord.col
		end
		return aCoord.row < bCoord.row
	end)
	return cloned
end

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
	self._worldContext = nil
	self._commanderContext = nil
	self._structureContext = nil
	self._structureEntityFactory = nil
	self._laneWaypoints = {} :: { Vector3 }

	self._runWaveStartedConnection = nil :: any
	self._runWaveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._enemySpawnedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
end

--[=[
	@within CombatContext
	Resolves dependent contexts, wires event handlers, and registers the heartbeat systems.
]=]
function CombatContext:KnitStart()
	CombatBaseContext:KnitStart()

	-- Lane movement sync still runs independently from combat AI ticks.
	CombatBaseContext:RegisterPollSystem("_enemyGameObjectSyncService", "PollPositions", "EnemyPositionPoll")

	-- Drive BT evaluation and executor updates for every active combat session.
	CombatBaseContext:RegisterSchedulerSystem("CombatTick", function()
		local dt = CombatBaseContext:GetSchedulerDeltaTime()
		for userId, activeCombat in pairs(self._combatLoopService:GetActiveCombats()) do
			if activeCombat.IsPaused then
				continue
			end

			self._processCombatTickCommand:Execute(userId, dt)
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

	CombatBaseContext:OnPlayerRemoving(function(player: Player)
		self:_OnPlayerRemoving(player)
	end, "_playerRemovingConnection")
end

-- Builds the cached waypoint list used by both startup and mid-wave enemy spawns.
function CombatContext:_CacheLaneWaypoints()
	local laneTilesResult = self._worldContext:GetLaneTiles()
	local goalPointResult = self._worldContext:GetGoalPoint()

	assert(
		laneTilesResult.success,
		string.format(
			"CombatContext: lane waypoint cache failed reading lane tiles (%s)",
			tostring(laneTilesResult.message or laneTilesResult.type or "unknown")
		)
	)
	assert(
		goalPointResult.success,
		string.format(
			"CombatContext: lane waypoint cache failed reading goal point (%s)",
			tostring(goalPointResult.message or goalPointResult.type or "unknown")
		)
	)

	local laneTiles = _sortLaneTiles(laneTilesResult.value)
	local goalPoint = goalPointResult.value
	local waypointHeight = goalPoint.Position.Y
	local waypoints = table.create(#laneTiles + 1)

	for _, tile in ipairs(laneTiles) do
		table.insert(waypoints, Vector3.new(tile.worldPos.X, waypointHeight, tile.worldPos.Z))
	end

	table.insert(waypoints, goalPoint.Position)
	self._laneWaypoints = waypoints
end

-- Starts combat for the active run wave and assigns behavior trees to existing enemies.
function CombatContext:_OnRunWaveStarted(waveNumber: number, isEndless: boolean)
	Catch(function()
		self:_CacheLaneWaypoints()
		Try(self._startCombatCommand:Execute(waveNumber, isEndless))
		return Ok(nil)
	end, "Combat:OnRunWaveStarted")
end

-- Stops combat when the run ends so no executors keep running after the lifecycle boundary.
function CombatContext:_OnRunEnded()
	Catch(function()
		Try(self._endCombatCommand:Execute())
		return Ok(nil)
	end, "Combat:OnRunEnded")
end

-- Ends combat cleanup for a wave and clears the enemy context after the last enemy is resolved.
function CombatContext:_OnRunWaveEnded(_waveNumber: number)
	Catch(function()
		Try(self._endCombatCommand:Execute())
		Try(self._enemyContext:CleanupAll())
		return Ok(nil)
	end, "Combat:OnRunWaveEnded")
end

-- Assigns lane waypoints to spawned enemies and backfills their behavior tree state if combat is already active.
function CombatContext:_OnEnemySpawned(entity: number, _role: string, _waveNumber: number)
	if #self._laneWaypoints == 0 then
		pcall(function()
			self:_CacheLaneWaypoints()
		end)
	end

	if #self._laneWaypoints > 0 then
		local success, err = pcall(function()
			self._enemyEntityFactory:SetWaypoints(entity, self._laneWaypoints)
		end)
		if not success then
			Result.MentionError("Combat:OnEnemySpawned", "Failed to assign lane waypoints", {
				EnemyEntity = entity,
				CauseMessage = err,
			}, "WaypointAssignmentFailed")
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
