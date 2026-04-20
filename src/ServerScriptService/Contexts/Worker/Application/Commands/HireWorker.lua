--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local Result = require(ReplicatedStorage.Utilities.Result)

type Result<T> = Result.Result<T>
local Ok = Result.Ok
local Try = Result.Try
local MentionSuccess = Result.MentionSuccess

--[[
    Hire Worker Application Service - ECS version

    Orchestrates: policy check → entity creation → persistence → client sync

    Flow:
    1. Policy check — worker type is valid (Domain)
    2. Create ECS entity (Infrastructure - EntityFactory)
    3. Persist to ProfileStore (Infrastructure - DataManager)
    4. Sync to client (Infrastructure - Charm atom)
]]

--[=[
	@class HireWorker
	Application command that hires a new worker: validates type, creates the ECS entity,
	persists to ProfileStore, and syncs to the client atom.
	@server
]=]
local HireWorker = {}
HireWorker.__index = HireWorker

export type THireWorker = typeof(setmetatable(
	{} :: {
		HirePolicy: any,
		EntityFactory: any,
		PersistenceService: any,
		SyncService: any,
		UndecidedSpawnService: any,
	},
	HireWorker
))

function HireWorker.new(): THireWorker
	return setmetatable({}, HireWorker)
end

function HireWorker:Init(registry: any, _name: string)
	self.HirePolicy = registry:Get("HirePolicy")
	self.EntityFactory = registry:Get("WorkerEntityFactory")
	self.PersistenceService = registry:Get("WorkerPersistenceService")
	self.SyncService = registry:Get("WorkerSyncService")
	self.UndecidedSpawnService = registry:Get("UndecidedSpawnService")
end

--[=[
	Hires a new worker of the given type for the player.
	@within HireWorker
	@param userId number
	@param workerType string
	@return Result<string> -- The new workerId on success
]=]
function HireWorker:Execute(userId: number, workerType: string): Result<string>
	-- 1. Policy: validate worker type (Domain layer)
	Try(self.HirePolicy:Check(workerType))

	-- 2. Generate unique worker ID
	local workerId = HttpService:GenerateGUID(false)

	-- 3. Create ECS entity with components (Infrastructure layer)
	local position = self.UndecidedSpawnService:GetSpawnPosition(userId)
	local entity = self.EntityFactory:CreateWorker(userId, workerId, workerType, position)

	-- 4. Persist to ProfileStore via DataManager (Infrastructure layer)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Try(self.PersistenceService:SaveWorkerEntity(player, entity))
	end

	-- 5. Sync to Charm atom for client (Infrastructure layer - legacy bridge)
	self.SyncService:CreateWorker(userId, workerId, workerType)
	self.SyncService:UpdateLastProductionTick(userId, workerId, os.time())

	-- Fire game event for cross-cutting concerns (sound, analytics, etc.)
	GameEvents.Bus:Emit(Events.Worker.WorkerHired, userId, workerId, workerType)
	MentionSuccess("Worker:HireWorker:Execute", "Hired worker and persisted initial worker state", {
		userId = userId,
		workerId = workerId,
		workerType = workerType,
	})

	return Ok(workerId)
end

return HireWorker
