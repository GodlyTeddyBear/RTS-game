--!strict

--[[
	Process Miner Mining Application Service

	Handles action-based mining for all active miners. Each miner performs a
	timed mining action; on completion they gain ore-specific XP and immediately
	begin the next action (continuous loop).

	Flow (called every tick):
	1. Query all entities with MiningStateComponent (active miners)
	2. MiningTickPolicy: verify ore exists, miner is near ore, and timer has elapsed
	3. If eligible: grant ore-specific XP, check level up, restart mining action
	4. Persist and sync changed workers
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)

type Result<T> = Result.Result<T>
local Ok = Result.Ok
local Try = Result.Try
local Catch = Result.Catch

local MINER_ROLES = { Miner = true }

local ProcessMinerMining = {}
ProcessMinerMining.__index = ProcessMinerMining

export type TProcessMinerMining = typeof(setmetatable({} :: {
	Registry: any,
	LevelService: any,
	EntityFactory: any,
	PersistenceService: any,
	SyncService: any,
	MiningTickPolicy: any,
	InventoryContext: any?,
	UpgradeContext: any?,
}, ProcessMinerMining))

function ProcessMinerMining.new(): TProcessMinerMining
	local self = setmetatable({}, ProcessMinerMining)
	return self
end

function ProcessMinerMining:Init(registry: any, _name: string)
	self.Registry = registry
	self.LevelService = registry:Get("WorkerLevelService")
	self.EntityFactory = registry:Get("WorkerEntityFactory")
	self.PersistenceService = registry:Get("WorkerPersistenceService")
	self.SyncService = registry:Get("WorkerSyncService")
	self.MiningTickPolicy = registry:Get("MiningTickPolicy")
end

function ProcessMinerMining:Start()
	self.InventoryContext = self.Registry:Get("InventoryContext")
	self.UpgradeContext = self.Registry:Get("UpgradeContext")
end

--- Process mining actions for all active miners.
--- Called by the production tick loop - each entity is isolated so one failure doesn't abort the rest.
function ProcessMinerMining:Execute()
	local currentTime = os.clock()
	local activeMiners = self.EntityFactory:QueryActiveMiners()

	for _, minerData in activeMiners do
		local assignment = minerData.Assignment
		if assignment and MINER_ROLES[assignment.Role] then
			Catch(function()
				self:_ProcessMiner(minerData, currentTime)
				return Ok(nil)
			end, "Worker:ProcessMinerMining")
		end
	end
end

--- Internal: check eligibility via policy and complete mining if eligible.
function ProcessMinerMining:_ProcessMiner(minerData: any, currentTime: number)
	local entity = minerData.Entity
	local worker = minerData.Worker
	local miningState = minerData.MiningState

	-- Policy: check ore exists, miner is near ore, and mining timer has elapsed
	local policyResult = self.MiningTickPolicy:Check(entity, worker, miningState, currentTime)
	if not policyResult.success then return end

	self:_CompleteMiningAction(entity, worker, miningState, policyResult.value)
end

--- Internal: handle a completed mining action for one miner.
function ProcessMinerMining:_CompleteMiningAction(entity: any, worker: any, miningState: any, eligibility: any)
	local oreId = eligibility.OreId
	local oreConfig = eligibility.OreConfig

	-- Calculate XP gained from this ore (Domain - pure lookup)
	local xpGained = self.LevelService:CalculateXPForMining(oreId)
	if self.UpgradeContext then
		local xpMult = self.UpgradeContext:GetWorkerXPMultiplier(worker.UserId)
		xpGained = math.floor(xpGained * xpMult)
	end
	local newXP = worker.Experience + xpGained

	-- Check for level up (Domain - pure calculation)
	local shouldLevelUp, newLevel, remainingXP = self.LevelService:CheckLevelUp(newXP, worker.Level)

	-- Update ECS components (Infrastructure)
	if shouldLevelUp then
		self.EntityFactory:LevelUpWorker(entity, newLevel, remainingXP)
	else
		self.EntityFactory:UpdateWorkerXP(entity, newXP)
	end

	-- Add mined ore to inventory — pause miner if inventory is full
	if oreConfig and self.InventoryContext then
		local addResult = self.InventoryContext:AddItemToInventory(worker.UserId, oreConfig.ItemId, 1)
		if not addResult.success then
			warn("[Worker:ProcessMinerMining] userId:", worker.UserId, "- Stopping miner, cannot add ore:", addResult.message)
			self.EntityFactory:StopMining(entity)
			self:_PersistAndSync(worker, entity, shouldLevelUp, newLevel, remainingXP, newXP)
			return
		end
	end

	-- Fire game event for cross-cutting concerns (sound, analytics, etc.)
	local itemId = oreConfig and oreConfig.ItemId or oreId
	GameEvents.Bus:Emit(Events.Worker.MiningCompleted, worker.UserId, worker.Id, oreId, itemId)

	-- Restart mining action immediately for continuous loop
	self.EntityFactory:StartMining(entity, oreId, miningState.MiningDuration)

	self:_PersistAndSync(worker, entity, shouldLevelUp, newLevel, remainingXP, newXP)
end

--- Persist worker entity and sync XP or level-up to client
function ProcessMinerMining:_PersistAndSync(
	worker: any,
	entity: any,
	shouldLevelUp: boolean,
	newLevel: number,
	remainingXP: number,
	newXP: number
)
	local player = Players:GetPlayerByUserId(worker.UserId)
	if player then
		Try(self.PersistenceService:SaveWorkerEntity(player, entity))
	end
	if shouldLevelUp then
		self.SyncService:LevelUpWorker(worker.UserId, worker.Id, newLevel)
		self.SyncService:UpdateWorkerXP(worker.UserId, worker.Id, remainingXP)
	else
		self.SyncService:UpdateWorkerXP(worker.UserId, worker.Id, newXP)
	end
end

return ProcessMinerMining
