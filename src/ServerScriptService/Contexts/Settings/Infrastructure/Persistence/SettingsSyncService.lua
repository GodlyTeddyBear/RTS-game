--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BaseSyncService = require(ReplicatedStorage.Utilities.BaseSyncService)
local SharedAtoms = require(ReplicatedStorage.Contexts.Settings.Sync.SharedAtoms)

local SettingsSyncService = setmetatable({}, { __index = BaseSyncService })
SettingsSyncService.__index = SettingsSyncService
SettingsSyncService.AtomKey = "settings"
SettingsSyncService.BlinkEventName = "SyncSettingsState"
SettingsSyncService.CreateAtom = SharedAtoms.CreateServerAtom

function SettingsSyncService.new()
	return setmetatable({}, SettingsSyncService)
end

function SettingsSyncService:LoadPlayerSettings(userId: number, settings: SharedAtoms.TSettingsData)
	self:LoadUserData(userId, SharedAtoms.CloneSettings(settings))
end

function SettingsSyncService:RemovePlayerSettings(userId: number)
	self:RemoveUserData(userId)
end

function SettingsSyncService:GetSettingsReadOnly(userId: number): SharedAtoms.TSettingsData?
	local settings = self:GetReadOnly(userId)
	return settings and SharedAtoms.CloneSettings(settings) or nil
end

function SettingsSyncService:SetSettings(userId: number, settings: SharedAtoms.TSettingsData)
	local nextSettings = SharedAtoms.CloneSettings(settings)
	self.Atom(function(current)
		local updated = table.clone(current)
		updated[userId] = nextSettings
		return updated
	end)
end

function SettingsSyncService:SetSoundSettings(userId: number, soundSettings: SharedAtoms.TSoundSettingsData)
	self.Atom(function(current)
		local updated = table.clone(current)
		local currentSettings = updated[userId] or SharedAtoms.CloneSettings(nil)
		local nextSettings = table.clone(currentSettings)
		nextSettings.Sound = SharedAtoms.CloneSoundSettings(soundSettings)
		updated[userId] = nextSettings
		return updated
	end)
end

return SettingsSyncService
