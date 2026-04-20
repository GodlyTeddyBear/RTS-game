--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Upgrade.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.UpgradeSyncClient)

local UpgradeSyncClient = setmetatable({}, { __index = BaseSyncClient })
UpgradeSyncClient.__index = UpgradeSyncClient

function UpgradeSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncUpgrades", "upgrades", SharedAtoms.CreateClientAtom)
	return setmetatable(self, UpgradeSyncClient)
end

function UpgradeSyncClient:GetUpgradesAtom()
	return self:GetAtom()
end

return UpgradeSyncClient
