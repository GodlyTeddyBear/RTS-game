--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Registry = require(ReplicatedStorage.Utilities.Registry)
local Result = require(ReplicatedStorage.Utilities.Result)
local WrapContext = require(ReplicatedStorage.Utilities.WrapContext)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)

local ServerScheduler = require(ServerScriptService.Scheduler.ServerScheduler)

local CombatLoopService = require(script.Parent.Infrastructure.Services.CombatLoopService)
local BehaviorTreeFactory = require(script.Parent.Infrastructure.Services.BehaviorTreeFactory)
local ExecutorRegistry = require(script.Parent.Executors.Base.ExecutorRegistry)
local LaneAdvanceExecutor = require(script.Parent.Executors.LaneAdvanceExecutor)
local IdleExecutor = require(script.Parent.Executors.IdleExecutor)
local BehaviorTreeTickPolicy = require(script.Parent.CombatDomain.Policies.BehaviorTreeTickPolicy)
local WaveCompletionPolicy = require(script.Parent.CombatDomain.Policies.WaveCompletionPolicy)
local CombatPerceptionService = require(script.Parent.CombatDomain.Services.CombatPerceptionService)

local StartCombat = require(script.Parent.Application.Commands.StartCombat)
local ProcessCombatTick = require(script.Parent.Application.Commands.ProcessCombatTick)
local EndCombat = require(script.Parent.Application.Commands.EndCombat)
local HandleGoalReached = require(script.Parent.Application.Commands.HandleGoalReached)

--[=[
	@class CombatContext
	Coordinates combat start, tick, cleanup, and enemy goal resolution for the lane-defense run.
	@server
]=]
local CombatContext = Knit.CreateService({
	Name = "CombatContext",
	Client = {},
})

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

-- Unwraps a required context dependency and raises immediately if the registry returned a failure.
local function _unwrapResult(result: any, label: string)
	if result.success then
		return result.value
	end

	local message = result.message
	if message == nil then
		message = result.type or "Unknown error"
	end

	error(string.format("%s failed: %s", label, tostring(message)))
	return result.value
end

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

-- Registers combat infrastructure, policies, and commands before the rest of the server starts ticking.
function CombatContext:KnitInit()
	local registry = Registry.new("Server")
	registry:Register("CombatLoopService", CombatLoopService.new(), "Infrastructure")
	registry:Register("BehaviorTreeFactory", BehaviorTreeFactory.new(), "Infrastructure")
	registry:Register("ExecutorRegistry", ExecutorRegistry.new(), "Infrastructure")
	registry:Register("BehaviorTreeTickPolicy", BehaviorTreeTickPolicy.new(), "Domain")
	registry:Register("WaveCompletionPolicy", WaveCompletionPolicy.new(), "Domain")
	registry:Register("CombatPerceptionService", CombatPerceptionService.new(), "Domain")
	registry:Register("StartCombat", StartCombat.new(), "Application")
	registry:Register("ProcessCombatTick", ProcessCombatTick.new(), "Application")
	registry:Register("EndCombat", EndCombat.new(), "Application")
	registry:Register("HandleGoalReached", HandleGoalReached.new(), "Application")
	registry:InitAll()

	self._registry = registry
	self._combatLoopService = registry:Get("CombatLoopService")
	self._executorRegistry = registry:Get("ExecutorRegistry")
	self._startCombatCommand = registry:Get("StartCombat")
	self._processCombatTickCommand = registry:Get("ProcessCombatTick")
	self._endCombatCommand = registry:Get("EndCombat")
	self._handleGoalReachedCommand = registry:Get("HandleGoalReached")

	self._enemyContext = nil
	self._enemyEntityFactory = nil
	self._enemyGameObjectSyncService = nil
	self._enemyModelFactory = nil
	self._worldContext = nil
	self._commanderContext = nil
	self._laneWaypoints = {} :: { Vector3 }

	self._runWaveStartedConnection = nil :: any
	self._runWaveEndedConnection = nil :: any
	self._runEndedConnection = nil :: any
	self._enemySpawnedConnection = nil :: any
	self._playerRemovingConnection = nil :: any
end

-- Resolves dependent contexts, wires event handlers, and registers the heartbeat systems.
function CombatContext:KnitStart()
	local enemyContext = Knit.GetService("EnemyContext")
	local worldContext = Knit.GetService("WorldContext")
	local commanderContext = Knit.GetService("CommanderContext")

	self._enemyContext = enemyContext
	self._worldContext = worldContext
	self._commanderContext = commanderContext

	self._enemyEntityFactory = _unwrapResult(enemyContext:GetEntityFactory(), "EnemyContext:GetEntityFactory")
	self._enemyGameObjectSyncService = _unwrapResult(enemyContext:GetGameObjectSyncService(), "EnemyContext:GetGameObjectSyncService")
	self._enemyModelFactory = _unwrapResult(enemyContext:GetModelFactory(), "EnemyContext:GetModelFactory")
	local enemyWorld = _unwrapResult(enemyContext:GetWorld(), "EnemyContext:GetWorld")
	local enemyComponents = _unwrapResult(enemyContext:GetComponents(), "EnemyContext:GetComponents")

	self._registry:Register("EnemyContext", enemyContext)
	self._registry:Register("EnemyEntityFactory", self._enemyEntityFactory)
	self._registry:Register("EnemyGameObjectSyncService", self._enemyGameObjectSyncService)
	self._registry:Register("EnemyModelFactory", self._enemyModelFactory)
	self._registry:Register("CommanderContext", commanderContext)
	self._registry:Register("WorldContext", worldContext)
	self._registry:Register("World", enemyWorld)
	self._registry:Register("Components", enemyComponents)

	-- Register the executor singletons before the first wave can enqueue actions.
	local laneAdvanceExecutor = LaneAdvanceExecutor.new()
	local idleExecutor = IdleExecutor.new()
	self._executorRegistry:Register("LaneAdvance", laneAdvanceExecutor)
	self._executorRegistry:Register("Idle", idleExecutor)

	self._registry:StartOrdered({ "Domain", "Infrastructure", "Application" })

	-- Cache lane waypoints once so spawn handlers only need to copy the path.
	self:_CacheLaneWaypoints()

	-- Lane movement sync still runs independently from combat AI ticks.
	ServerScheduler:RegisterSystem(function()
		self._enemyGameObjectSyncService:PollPositions()
	end, "EnemyPositionPoll")

	-- Drive BT evaluation and executor updates for every active combat session.
	ServerScheduler:RegisterSystem(function()
		local dt = ServerScheduler:GetDeltaTime()
		for userId, activeCombat in pairs(self._combatLoopService:GetActiveCombats()) do
			if activeCombat.IsPaused then
				continue
			end
			self._processCombatTickCommand:Execute(userId, dt)
		end
	end, "CombatTick")

	self._runWaveStartedConnection = GameEvents.Bus:On(GameEvents.Events.Run.WaveStarted, function(waveNumber: number, isEndless: boolean)
		self:_OnRunWaveStarted(waveNumber, isEndless)
	end)

	self._runWaveEndedConnection = GameEvents.Bus:On(GameEvents.Events.Run.WaveEnded, function(waveNumber: number)
		self:_OnRunWaveEnded(waveNumber)
	end)

	self._runEndedConnection = GameEvents.Bus:On(GameEvents.Events.Run.RunEnded, function()
		self:_OnRunEnded()
	end)

	self._enemySpawnedConnection = GameEvents.Bus:On(
		GameEvents.Events.Wave.EnemySpawned,
		function(entity: number, role: string, waveNumber: number)
			self:_OnEnemySpawned(entity, role, waveNumber)
		end
	)

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player: Player)
		self:_OnPlayerRemoving(player)
	end)
end

-- Builds the cached waypoint list used by both startup and mid-wave enemy spawns.
function CombatContext:_CacheLaneWaypoints()
	local laneTilesResult = self._worldContext:GetLaneTiles()
	local goalPointResult = self._worldContext:GetGoalPoint()

	if not laneTilesResult.success then
		Result.MentionError("Combat:KnitStart", "Unable to read lane tiles", {
			CauseType = laneTilesResult.type,
			CauseMessage = laneTilesResult.message,
		}, laneTilesResult.type)
		self._laneWaypoints = {}
		return
	end

	if not goalPointResult.success then
		Result.MentionError("Combat:KnitStart", "Unable to read goal point", {
			CauseType = goalPointResult.type,
			CauseMessage = goalPointResult.message,
		}, goalPointResult.type)
		self._laneWaypoints = {}
		return
	end

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

-- Exposes the active combat loop service for other contexts that need to query or control it.
function CombatContext:GetCombatLoopService(): Result.Result<any>
	return Ok(self._combatLoopService)
end

-- Disconnects listeners and stops combat so server shutdown leaves no active tick work behind.
function CombatContext:Destroy()
	Catch(function()
		Try(self._endCombatCommand:Execute())
		return Ok(nil)
	end, "Combat:Destroy")

	if self._runWaveStartedConnection then
		self._runWaveStartedConnection:Disconnect()
	end
	if self._runWaveEndedConnection then
		self._runWaveEndedConnection:Disconnect()
	end
	if self._runEndedConnection then
		self._runEndedConnection:Disconnect()
	end
	if self._enemySpawnedConnection then
		self._enemySpawnedConnection:Disconnect()
	end
	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
	end
end

WrapContext(CombatContext, "Combat")

return CombatContext
