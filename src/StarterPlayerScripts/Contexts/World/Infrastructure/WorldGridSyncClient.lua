--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.World.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.WorldSyncClient)

local WorldGridSyncClient = setmetatable({}, { __index = BaseSyncClient })
WorldGridSyncClient.__index = WorldGridSyncClient

function WorldGridSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncWorldGrid", "WorldGrid", SharedAtoms.CreateClientAtom)
	return setmetatable(self, WorldGridSyncClient)
end

function WorldGridSyncClient:Start()
	BaseSyncClient.Start(self)
end

function WorldGridSyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return WorldGridSyncClient
