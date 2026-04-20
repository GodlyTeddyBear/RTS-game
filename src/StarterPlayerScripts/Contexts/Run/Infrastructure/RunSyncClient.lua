--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Run.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.RunSyncClient)

--[=[
	@class RunSyncClient
	Wraps the client-side run sync atom and Blink listener.
	@client
]=]
local RunSyncClient = setmetatable({}, { __index = BaseSyncClient })
RunSyncClient.__index = RunSyncClient

--[=[
	Creates a new client sync wrapper for the run state atom.
	@within RunSyncClient
	@return RunSyncClient -- The new client sync wrapper.
]=]
function RunSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncRunState", "runState", SharedAtoms.CreateClientAtom)
	return setmetatable(self, RunSyncClient)
end

--[=[
	Starts listening for server run-state sync payloads.
	@within RunSyncClient
]=]
function RunSyncClient:Start()
	BaseSyncClient.Start(self)
end

--[=[
	Returns the local run-state atom for subscriptions.
	@within RunSyncClient
	@return any -- The client Charm atom.
]=]
function RunSyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return RunSyncClient
