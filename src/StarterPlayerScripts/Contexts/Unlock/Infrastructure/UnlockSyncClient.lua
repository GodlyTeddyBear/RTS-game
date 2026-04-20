--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Unlock.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.UnlockSyncClient)

local UnlockSyncClient = setmetatable({}, { __index = BaseSyncClient })
UnlockSyncClient.__index = UnlockSyncClient

function UnlockSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncUnlocks", "unlocks", SharedAtoms.CreateClientAtom)
	return setmetatable(self, UnlockSyncClient)
end

function UnlockSyncClient:GetUnlocksAtom()
	return self:GetAtom()
end

return UnlockSyncClient
