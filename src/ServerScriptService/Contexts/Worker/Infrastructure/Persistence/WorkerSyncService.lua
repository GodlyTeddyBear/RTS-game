--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Worker.Sync.SharedAtoms)
local WorkerTypes = require(ReplicatedStorage.Contexts.Worker.Types.WorkerTypes)

type TWorker = WorkerTypes.TWorker

--[[
	Worker Sync Service

	Manages worker state synchronization. Extends BaseSyncService for
	CharmSync + Blink wiring; defines only worker-specific mutations.

	IMPORTANT: All worker atom mutations are centralized in this service.
]]

local WorkerSyncService = setmetatable({}, { __index = BaseSyncService })
WorkerSyncService.__index = WorkerSyncService
WorkerSyncService.AtomKey = "workers"
WorkerSyncService.BlinkEventName = "SyncWorkers"
WorkerSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function WorkerSyncService.new()
	return setmetatable({}, WorkerSyncService)
end

--[[
	READ-ONLY GETTERS
]]

--- Get all workers for a user (deep clone to prevent mutations)
function WorkerSyncService:GetWorkersReadOnly(userId: number): { [string]: TWorker }?
	return self:GetReadOnly(userId)
end

--- Get a specific worker (deep clone to prevent mutations)
function WorkerSyncService:GetWorkerReadOnly(userId: number, workerId: string): TWorker?
	return self:GetNestedReadOnly(userId, workerId)
end

--- Returns the server-side atom
function WorkerSyncService:GetWorkersAtom()
	return self:GetAtom()
end

--[[
	CENTRALIZED MUTATION METHODS
]]

local function cloneWorker(current: any, userId: number, workerId: string): (any, any, any)
	local updated = table.clone(current)
	updated[userId] = table.clone(updated[userId])
	updated[userId][workerId] = table.clone(updated[userId][workerId])
	return updated, updated[userId], updated[userId][workerId]
end

--- Bulk load workers for a user (used when loading persisted data on join)
function WorkerSyncService:LoadUserWorkers(userId: number, workersData: { [string]: TWorker })
	local normalized: { [string]: TWorker } = {}
	for workerId, worker in workersData do
		local workerClone = table.clone(worker :: any)
		if workerClone.Rank == nil then
			workerClone.Rank = workerClone.Type or "Apprentice"
		end
		workerClone.Type = nil
		normalized[workerId] = workerClone :: TWorker
	end
	self:LoadUserData(userId, normalized)
end

--- Remove all workers for a user (cleanup on player leave)
function WorkerSyncService:RemoveUserWorkers(userId: number)
	self:RemoveUserData(userId)
end

--- Create a new worker for a user
function WorkerSyncService:CreateWorker(userId: number, workerId: string, workerType: string)
	self.Atom(function(current)
		local updated = table.clone(current)

		if not updated[userId] then
			updated[userId] = {}
		else
			updated[userId] = table.clone(updated[userId])
		end

		updated[userId][workerId] = {
			Id = workerId,
			Rank = workerType,
			Level = 1,
			Experience = 0,
			AssignedTo = "Undecided",
			TaskTarget = nil,
			LastProductionTick = os.time(),
		}

		return updated
	end)
end

--- Assign a worker to a production line
function WorkerSyncService:AssignWorker(userId: number, workerId: string, productionLine: string)
	self.Atom(function(current)
		local updated, _, workerClone = cloneWorker(current, userId, workerId)
		workerClone.AssignedTo = productionLine
		return updated
	end)
end

--- Assign a worker to a role (alias for AssignWorker)
function WorkerSyncService:AssignRole(userId: number, workerId: string, roleId: string)
	self:AssignWorker(userId, workerId, roleId)
end

--- Assign a role-specific task target (e.g. ore type for Miner)
--- Pass nil to clear the target
function WorkerSyncService:AssignTaskTarget(userId: number, workerId: string, target: string?)
	self.Atom(function(current)
		local updated, _, workerClone = cloneWorker(current, userId, workerId)
		workerClone.TaskTarget = target
		return updated
	end)
end

--- Update worker XP
function WorkerSyncService:UpdateWorkerXP(userId: number, workerId: string, newXP: number)
	self.Atom(function(current)
		local updated, _, workerClone = cloneWorker(current, userId, workerId)
		workerClone.Experience = newXP
		return updated
	end)
end

--- Level up a worker
function WorkerSyncService:LevelUpWorker(userId: number, workerId: string, newLevel: number)
	self.Atom(function(current)
		local updated, _, workerClone = cloneWorker(current, userId, workerId)
		workerClone.Level = newLevel
		return updated
	end)
end

--- Update worker rank
function WorkerSyncService:UpdateWorkerRank(userId: number, workerId: string, rankId: string)
	self.Atom(function(current)
		local updated, _, workerClone = cloneWorker(current, userId, workerId)
		workerClone.Rank = rankId
		return updated
	end)
end

--- Update last production tick timestamp
function WorkerSyncService:UpdateLastProductionTick(userId: number, workerId: string, timestamp: number)
	self.Atom(function(current)
		local updated, _, workerClone = cloneWorker(current, userId, workerId)
		workerClone.LastProductionTick = timestamp
		return updated
	end)
end

return WorkerSyncService
