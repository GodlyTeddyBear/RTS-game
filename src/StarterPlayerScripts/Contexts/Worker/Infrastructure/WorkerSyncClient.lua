--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Worker.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.WorkerSyncClient)

--[=[
	@class WorkerSyncClient
	Client-side sync for worker state. Inherits from BaseSyncClient to receive and maintain worker atoms.
	@client
]=]

local WorkerSyncClient = setmetatable({}, { __index = BaseSyncClient })
WorkerSyncClient.__index = WorkerSyncClient

--[=[
	Create a new WorkerSyncClient.
	@within WorkerSyncClient
	@return WorkerSyncClient -- New instance
]=]
function WorkerSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncWorkers", "workers", SharedAtoms.CreateClientAtom)
	return setmetatable(self, WorkerSyncClient)
end

--[=[
	Get the workers atom.
	@within WorkerSyncClient
	@return Atom -- Atom containing workers table { [workerId]: TWorker }
]=]
function WorkerSyncClient:GetWorkersAtom()
	return self:GetAtom()
end

return WorkerSyncClient
