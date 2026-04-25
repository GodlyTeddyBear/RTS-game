--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Base.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.BaseSyncClient)

local BaseSyncClientImpl = {}
BaseSyncClientImpl.__index = BaseSyncClientImpl
setmetatable(BaseSyncClientImpl, BaseSyncClient)

function BaseSyncClientImpl.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncBase", "base", SharedAtoms.CreateClientAtom)
	return setmetatable(self, BaseSyncClientImpl)
end

function BaseSyncClientImpl:Start()
	BaseSyncClient.Start(self)
end

function BaseSyncClientImpl:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return BaseSyncClientImpl
