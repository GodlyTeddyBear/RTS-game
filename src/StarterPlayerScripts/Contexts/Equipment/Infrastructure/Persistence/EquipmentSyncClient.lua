--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Equipment.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.EquipmentSyncClient)

local EquipmentSyncClient = setmetatable({}, { __index = BaseSyncClient })
EquipmentSyncClient.__index = EquipmentSyncClient

function EquipmentSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncEquipment", "EquipmentState", SharedAtoms.CreateClientAtom)
	return setmetatable(self, EquipmentSyncClient)
end

function EquipmentSyncClient:Start()
	BaseSyncClient.Start(self)
end

function EquipmentSyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return EquipmentSyncClient
