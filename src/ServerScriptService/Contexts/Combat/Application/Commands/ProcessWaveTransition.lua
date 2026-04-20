--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local NPCConfig = require(ServerScriptService.Contexts.NPC.Config.NPCConfig)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)
local MentionSuccess = Result.MentionSuccess

local Ok = Result.Ok
local Try = Result.Try

--[=[
	@class ProcessWaveTransition
	Application command that handles the transition between combat waves.

	Orchestration order: pause loop → clear adventurer commands → destroy
	enemy models → clear dungeon wave → pathfind adventurers to new spawn
	points → spawn next enemy wave → assign BTs → resume loop.
	@server
]=]
local ProcessWaveTransition = {}
ProcessWaveTransition.__index = ProcessWaveTransition

export type TProcessWaveTransition = typeof(setmetatable({}, ProcessWaveTransition))

function ProcessWaveTransition.new(): TProcessWaveTransition
	return setmetatable({}, ProcessWaveTransition)
end

function ProcessWaveTransition:Init(registry: any, _name: string)
	self.Registry = registry
	self.BehaviorTreeFactory = registry:Get("BehaviorTreeFactory")
	self.CombatLoopService = registry:Get("CombatLoopService")
	self.TargetSelector = registry:Get("TargetSelector")
end

function ProcessWaveTransition:Start()
	self.NPCEntityFactory = self.Registry:Get("NPCEntityFactory")
	self.NPCModelFactory = self.Registry:Get("NPCModelFactory")
	self.NPCGameObjectSyncService = self.Registry:Get("GameObjectSyncService")
	self.NPCContext = self.Registry:Get("NPCContext")
	self.DungeonContext = self.Registry:Get("DungeonContext")
	self.World = self.Registry:Get("World")
	self.Components = self.Registry:Get("Components")
	self.LockOnService = self.Registry:Get("LockOnService")
end

--[=[
	Execute a wave transition for a user.

	:::caution
	The combat loop is paused for the duration of this call and resumed
	inside `_StartNextWave` once the new wave is ready. Adventurer
	pathfinding runs asynchronously — the loop stays paused until the
	`onComplete` callback fires.
	:::
	@within ProcessWaveTransition
	@param userId number
	@param zoneId string
	@param nextWaveNumber number
	@return Result.Result<nil>
	@yields
]=]
--[=[
	Execute a wave transition for a user.

	Pauses the combat loop, clears old wave data, destroys enemy models,
	pathfinds adventurers to new spawn points, and spawns the next wave.
	The loop remains paused until pathfinding completes and the new wave spawns.

	:::caution
	Adventurer pathfinding runs asynchronously — the loop stays paused until
	the `onComplete` callback fires inside `_PathfindAdventurers`.
	:::
	@within ProcessWaveTransition
	@param userId number
	@param zoneId string
	@param nextWaveNumber number
	@return Result.Result<nil>
	@yields
]=]
function ProcessWaveTransition:Execute(userId: number, zoneId: string, nextWaveNumber: number): Result.Result<nil>
	-- Step 1: Pause the combat loop to prevent ticks during transition
	self.CombatLoopService:PauseCombat(userId)
	MentionSuccess("Combat:ProcessWaveTransition:Wave", "userId: " .. userId .. " - Transitioning to wave " .. nextWaveNumber)
	GameEvents.Bus:Emit(Events.Combat.WaveTransitionStarted, userId, nextWaveNumber)

	-- Step 2: Clear all pending player commands from adventurers
	self:_ClearAdventurerCommands(userId)

	-- Step 3: Destroy all enemy models and entities from the current wave
	self:_DestroyAllEnemies(userId)

	-- Step 4: Get new spawn points from dungeon context and clear wave data
	local clearResult = Try(self.DungeonContext:ClearWave(userId))
	local newSpawnPoints = clearResult.SpawnPoints

	-- Step 5: Validate new spawn points; resume if unavailable (edge case)
	if not newSpawnPoints or #newSpawnPoints == 0 then
		self.CombatLoopService:ResumeCombat(userId)
		return Ok(nil)
	end

	-- Step 6: Pathfind adventurers to new spawn points asynchronously; loop remains paused until complete
	local aliveAdventurers = self.NPCEntityFactory:QueryAliveAdventurers(userId)
	self:_PathfindAdventurers(aliveAdventurers, newSpawnPoints, function()
		self:_StartNextWave(userId, zoneId, nextWaveNumber, newSpawnPoints)
	end)

	return Ok(nil)
end

-- Clear any pending player commands from adventurers before pathfinding to new positions.
function ProcessWaveTransition:_ClearAdventurerCommands(userId: number)
	local aliveAdventurers = self.NPCEntityFactory:QueryAliveAdventurers(userId)
	for _, entity in aliveAdventurers do
		self.NPCEntityFactory:ClearPlayerCommand(entity)
	end
end

-- Destroy all enemy entities and models from the current wave.
function ProcessWaveTransition:_DestroyAllEnemies(userId: number)
	local allEntities = self.NPCEntityFactory:QueryAllEntities(userId)
	for _, entity in ipairs(allEntities) do
		local identity = self.NPCEntityFactory:GetIdentity(entity)
		if identity and not identity.IsAdventurer then
			self.NPCGameObjectSyncService:DeleteEntity(entity)
			self.NPCEntityFactory:DeleteEntity(entity)
		end
	end
end

-- Spawn the next enemy wave and assign behavior trees to all new enemies.
function ProcessWaveTransition:_StartNextWave(userId: number, zoneId: string, nextWaveNumber: number, spawnPoints: { any })
	-- Spawn new enemies from the dungeon context
	local spawnResult = self.NPCContext:SpawnEnemyWaveForUser(userId, nextWaveNumber, zoneId, spawnPoints)
	local enemyEntities = spawnResult.success and spawnResult.value or {}

	-- Assign behavior trees to all spawned enemies and attach lock-on constraints
	if enemyEntities and #enemyEntities > 0 then
		self:_AssignBTsToEnemies(enemyEntities)
		for _, entity in ipairs(enemyEntities) do
			self.LockOnService:AttachConstraint(entity)
		end
	end

	-- Update combat state: set wave number and resume ticking
	self.CombatLoopService:SetCurrentWave(userId, nextWaveNumber)
	self.CombatLoopService:ResumeCombat(userId)

	MentionSuccess(
		"Combat:ProcessWaveTransition:Wave",
		"userId: " .. userId .. " - Wave " .. nextWaveNumber .. " started with " .. #enemyEntities .. " enemies"
	)
	GameEvents.Bus:Emit(Events.Combat.WaveTransitionComplete, userId, nextWaveNumber)
end

-- Asynchronously pathfind all alive adventurers to new spawn points. Calls onComplete when all arrive.
function ProcessWaveTransition:_PathfindAdventurers(
	adventurerEntities: { any },
	spawnPoints: { any },
	onComplete: () -> ()
)
	-- Early return if no adventurers to move
	if #adventurerEntities == 0 then
		onComplete()
		return
	end

	-- Track completion: fire onComplete when all adventurers have arrived
	local arrivedCount = 0
	local totalCount = #adventurerEntities

	local function onArrived()
		arrivedCount += 1
		if arrivedCount >= totalCount then
			onComplete()
		end
	end

	-- Distribute adventurers to spawn points in round-robin order
	for i, entity in ipairs(adventurerEntities) do
		local modelRef = self.NPCEntityFactory:GetModelRef(entity)
		if not modelRef or not modelRef.Instance then
			onArrived()
			continue
		end

		local model = modelRef.Instance
		-- Calculate round-robin spawn point (distributes evenly)
		local spawnPoint = spawnPoints[((i - 1) % #spawnPoints) + 1]
		local targetPos = spawnPoint.Position or Vector3.new(0, 5, 0)
		local humanoid = model:FindFirstChildOfClass("Humanoid")

		if humanoid then
			-- Use Humanoid pathfinding if available (animated walk)
			self.NPCEntityFactory:SetLocomotionState(entity, "Moving")
			task.spawn(function()
				humanoid:MoveTo(targetPos)
				humanoid.MoveToFinished:Wait()
				self.NPCEntityFactory:SetLocomotionState(entity, "Idle")
				onArrived()
			end)
		else
			-- Fallback: direct position update (ragdoll or no humanoid)
			self.NPCModelFactory:UpdatePosition(model, CFrame.new(targetPos))
			self.NPCEntityFactory:SetLocomotionState(entity, "Idle")
			onArrived()
		end
	end
end

-- Assign behavior configs and trees to all spawned enemy entities with staggered tick intervals.
function ProcessWaveTransition:_AssignBTsToEnemies(enemyEntities: { any })
	for _, entity in ipairs(enemyEntities) do
		local identity = self.NPCEntityFactory:GetIdentity(entity)
		if not identity then
			continue
		end

		-- Initialize behavior config from NPC type defaults
		self.NPCEntityFactory:SetBehaviorConfigFromDefaults(entity, identity.NPCType)

		-- Stagger behavior tree ticks so all enemies don't tick simultaneously
		local tickInterval = NPCConfig.BT_TICK_MIN_INTERVAL
			+ math.random() * (NPCConfig.BT_TICK_MAX_INTERVAL - NPCConfig.BT_TICK_MIN_INTERVAL)

		local tree = self.BehaviorTreeFactory:CreateTree(identity.NPCType, false)
		if tree then
			self.NPCEntityFactory:SetBehaviorTree(entity, tree, tickInterval)
		end
	end
end

return ProcessWaveTransition
