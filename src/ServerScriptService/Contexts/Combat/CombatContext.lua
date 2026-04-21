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
local CombatMovementService = require(script.Parent.Infrastructure.Services.CombatMovementService)

local StartCombat = require(script.Parent.Application.Commands.StartCombat)
local ProcessCombatTick = require(script.Parent.Application.Commands.ProcessCombatTick)
local EndCombat = require(script.Parent.Application.Commands.EndCombat)
local HandleGoalReached = require(script.Parent.Application.Commands.HandleGoalReached)

local CombatContext = Knit.CreateService({
	Name = "CombatContext",
	Client = {},
})

local Catch = Result.Catch
local Ok = Result.Ok
local Try = Result.Try

local function _unwrapResult(result: any, label: string)
	assert(result.success, string.format("%s failed: %s", label, result.message))
	return result.value
end

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

function CombatContext:KnitInit()
	local registry = Registry.new("Server")
	registry:Register("CombatLoopService", CombatLoopService.new(), "Infrastructure")
	registry:Register("CombatMovementService", CombatMovementService.new(), "Infrastructure")
	registry:Register("StartCombat", StartCombat.new(), "Application")
	registry:Register("ProcessCombatTick", ProcessCombatTick.new(), "Application")
	registry:Register("EndCombat", EndCombat.new(), "Application")
	registry:Register("HandleGoalReached", HandleGoalReached.new(), "Application")
	registry:InitAll()

	self._registry = registry
	self._combatLoopService = registry:Get("CombatLoopService")
	self._movementService = registry:Get("CombatMovementService")
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

	self._registry:StartOrdered({ "Infrastructure", "Application" })

	self._movementService:SetGoalReachedHandler(function(entity: any)
		self:_OnGoalReached(entity)
	end)

	self:_CacheLaneWaypoints()

	ServerScheduler:RegisterSystem(function()
		self._enemyGameObjectSyncService:PollPositions()
	end, "EnemyPositionPoll")

	ServerScheduler:RegisterSystem(function()
		self._processCombatTickCommand:Execute()
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

function CombatContext:_OnRunWaveStarted(waveNumber: number, isEndless: boolean)
	Catch(function()
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

function CombatContext:_OnRunWaveEnded(_waveNumber: number)
	Catch(function()
		Try(self._endCombatCommand:Execute())
		Try(self._enemyContext:CleanupAll())
		return Ok(nil)
	end, "Combat:OnRunWaveEnded")
end

function CombatContext:_OnEnemySpawned(entity: number, _role: string, _waveNumber: number)
	if #self._laneWaypoints == 0 then
		return
	end

	local success, err = pcall(function()
		self._enemyEntityFactory:SetWaypoints(entity, self._laneWaypoints)
	end)
	if not success then
		Result.MentionError("Combat:OnEnemySpawned", "Failed to assign lane waypoints", {
			EnemyEntity = entity,
			CauseMessage = err,
		}, "WaypointAssignmentFailed")
	end
end

function CombatContext:_OnGoalReached(entity: any)
	local result = self._handleGoalReachedCommand:Execute(entity)
	if not result.success then
		Result.MentionError("Combat:OnGoalReached", "Failed to resolve goal reached", {
			EnemyEntity = entity,
			CauseType = result.type,
			CauseMessage = result.message,
		}, result.type)
	end
end

function CombatContext:_OnPlayerRemoving(_player: Player)
	if #Players:GetPlayers() <= 1 then
		self:_OnRunEnded()
	end
end

function CombatContext:GetCombatLoopService(): Result.Result<any>
	return Ok(self._combatLoopService)
end

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
