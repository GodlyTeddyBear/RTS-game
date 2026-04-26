--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Inventory.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.InventorySyncClient)

local InventorySyncClient = setmetatable({}, { __index = BaseSyncClient })
InventorySyncClient.__index = InventorySyncClient

function InventorySyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncInventory", "inventories", SharedAtoms.CreateClientAtom)
	return setmetatable(self, InventorySyncClient)
end

function InventorySyncClient:Start()
	BaseSyncClient.Start(self)
end

function InventorySyncClient:GetAtom()
	return BaseSyncClient.GetAtom(self)
end

return InventorySyncClient
