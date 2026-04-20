--!strict

--[[
	Process Harvesting Application Service

	Handles action-based harvesting for all active Lumberjacks, Herbalists, and Farmers.
	Each worker performs a timed harvest action; on completion they gain target-specific
	XP and immediately begin the next action (continuous loop).

	Reuses the MiningStateComponent for harvest state tracking (same ECS field).

	Flow (called every tick):
	1. Query all entities with MiningStateComponent for Lumberjack/Herbalist/Farmer roles
	2. HarvestTickPolicy: verify target exists, worker is near target, and timer has elapsed
	3. If eligible: grant target-specific XP, check level up, restart harvest action
	4. Persist and sync changed workers

	NOTE: This system is registered but NOT started in WorkerContext until lot zones
	(Forest/Garden/Farm) are implemented and the feature is ready to deploy.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TreeConfig = require(ReplicatedStorage.Contexts.Worker.Config.TreeConfig)
local PlantConfig = require(ReplicatedStorage.Contexts.Worker.Config.PlantConfig)
local CropConfig = require(ReplicatedStorage.Contexts.Worker.Config.CropConfig)
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)

type Result<T> = Result.Result<T>
local Ok = Result.Ok
local Try = Result.Try
local Catch = Result.Catch

local HARVEST_ROLES = { Lumberjack = true, Herbalist = true, Farmer = true }

local ROLE_CONFIG = {
	Lumberjack = {
		Config = TreeConfig,
		FolderName = "Default",
		GetFolder = function(lotContext: any, userId: number)
			return lotContext:GetForestFolderForUser(userId)
		end,
	},
	Herbalist = {
		Config = PlantConfig,
		FolderName = "Default",
		GetFolder = function(lotContext: any, userId: number)
			return lotContext:GetGardenFolderForUser(userId)
		end,
	},
	Farmer = {
		Config = CropConfig,
		FolderName = "Default",
		GetFolder = function(lotContext: any, userId: number)
			return lotContext:GetFarmFolderForUser(userId)
		end,
	},
}

--[=[
	@class ProcessHarvesting
	Tick system that drives timed harvest actions for Lumberjack, Herbalist, and Farmer
	workers. Reuses `MiningStateComponent` for action-state tracking.
	@server
]=]
local ProcessHarvesting = {}
ProcessHarvesting.__index = ProcessHarvesting

export type TProcessHarvesting = typeof(setmetatable({} :: {
	Registry: any,
	LevelService: any,
	EntityFactory: any,
	PersistenceService: any,
	SyncService: any,
	HarvestTickPolicy: any,
	InventoryContext: any?,
}, ProcessHarvesting))

function ProcessHarvesting.new(): TProcessHarvesting
	return setmetatable({}, ProcessHarvesting)
end

function ProcessHarvesting:Init(registry: any, _name: string)
	self.Registry = registry
	self.LevelService = registry:Get("WorkerLevelService")
	self.EntityFactory = registry:Get("WorkerEntityFactory")
	self.PersistenceService = registry:Get("WorkerPersistenceService")
	self.SyncService = registry:Get("WorkerSyncService")
	self.HarvestTickPolicy = registry:Get("HarvestTickPolicy")
end

function ProcessHarvesting:Start()
	self.InventoryContext = self.Registry:Get("InventoryContext")
end

--[=[
	Processes one harvest tick for every active harvesting worker.
	Each entity is wrapped in `Catch` so a single failure does not abort the rest.
	@within ProcessHarvesting
]=]
function ProcessHarvesting:Execute()
	local currentTime = os.clock()
	local activeHarvestWorkers = self.EntityFactory:QueryActiveMiners()

	for _, workerData in activeHarvestWorkers do
		local assignment = self.EntityFactory:GetAssignment(workerData.Entity)
		if assignment and HARVEST_ROLES[assignment.Role] then
			Catch(function()
				self:_ProcessWorker(workerData, currentTime, assignment.Role)
				return Ok(nil)
			end, "Worker:ProcessHarvesting")
		end
	end
end

--- @within ProcessHarvesting
--- @private
function ProcessHarvesting:_ProcessWorker(workerData: any, currentTime: number, role: string)
	local entity = workerData.Entity
	local worker = workerData.Worker
	local harvestState = workerData.MiningState

	local roleConfig = ROLE_CONFIG[role]
	local policyResult = self.HarvestTickPolicy:Check(
		entity, worker, harvestState, currentTime,
		roleConfig.Config, roleConfig.GetFolder, roleConfig.FolderName
	)
	if not policyResult.success then return end

	self:_CompleteHarvestAction(entity, worker, harvestState, policyResult.value, role)
end

--- @within ProcessHarvesting
--- @private
function ProcessHarvesting:_CompleteHarvestAction(entity: any, worker: any, harvestState: any, ctx: any, _role: string)
	local targetId = ctx.TargetId
	local targetConfig = ctx.TargetConfig

	-- XP field varies by config type — fall back to XPPerMine if specific field missing
	local DEFAULT_HARVEST_XP = 5
	local xpGained = targetConfig.XPPerChop or targetConfig.XPPerHarvest or targetConfig.XPPerMine or DEFAULT_HARVEST_XP
	local newXP = worker.Experience + xpGained

	local shouldLevelUp, newLevel, remainingXP = self.LevelService:CheckLevelUp(newXP, worker.Level)

	if shouldLevelUp then
		self.EntityFactory:LevelUpWorker(entity, newLevel, remainingXP)
	else
		self.EntityFactory:UpdateWorkerXP(entity, newXP)
	end

	-- Add harvested item to inventory — pause worker if inventory is full
	if targetConfig and self.InventoryContext then
		local addResult = self.InventoryContext:AddItemToInventory(worker.UserId, targetConfig.ItemId, 1)
		if not addResult.success then
			warn("[Worker:ProcessHarvesting] userId:", worker.UserId, "- Stopping worker, cannot add item:", addResult.message)
			self.EntityFactory:StopMining(entity)
			self:_PersistAndSync(worker, entity, shouldLevelUp, newLevel, remainingXP, newXP)
			return
		end
	end

	GameEvents.Bus:Emit(Events.Worker.MiningCompleted, worker.UserId, worker.Id, targetId, targetConfig and targetConfig.ItemId or targetId)

	-- Restart harvest action immediately for continuous loop
	self.EntityFactory:StartMining(entity, targetId, harvestState.MiningDuration, harvestState.AnimationState)

	self:_PersistAndSync(worker, entity, shouldLevelUp, newLevel, remainingXP, newXP)
end

--- @within ProcessHarvesting
--- @private
function ProcessHarvesting:_PersistAndSync(worker: any, entity: any, shouldLevelUp: boolean, newLevel: number, remainingXP: number, newXP: number)
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

return ProcessHarvesting
