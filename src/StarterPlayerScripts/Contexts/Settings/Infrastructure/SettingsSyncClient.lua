--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncClient = require(ReplicatedStorage.Utilities.BaseSyncClient)
local SharedAtoms = require(ReplicatedStorage.Contexts.Settings.Sync.SharedAtoms)
local BlinkClient = require(ReplicatedStorage.Network.Generated.SettingsSyncClient)

local SettingsSyncClient = setmetatable({}, { __index = BaseSyncClient })
SettingsSyncClient.__index = SettingsSyncClient

function SettingsSyncClient.new()
	local self = BaseSyncClient.new(BlinkClient, "SyncSettingsState", "settings", SharedAtoms.CreateClientAtom)
	return setmetatable(self, SettingsSyncClient)
end

function SettingsSyncClient:GetSettingsAtom()
	return self:GetAtom()
end

return SettingsSyncClient
