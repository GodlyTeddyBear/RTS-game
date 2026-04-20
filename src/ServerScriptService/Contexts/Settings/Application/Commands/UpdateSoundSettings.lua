--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local SharedAtoms = require(ReplicatedStorage.Contexts.Settings.Sync.SharedAtoms)

local Ok = Result.Ok
local Try = Result.Try

local UpdateSoundSettings = {}
UpdateSoundSettings.__index = UpdateSoundSettings

function UpdateSoundSettings.new()
	return setmetatable({}, UpdateSoundSettings)
end

function UpdateSoundSettings:Init(registry: any, _name: string)
	self.Validator = registry:Get("SoundSettingsValidator")
	self.PersistenceService = registry:Get("SettingsPersistenceService")
	self.SyncService = registry:Get("SettingsSyncService")
end

function UpdateSoundSettings:Execute(
	player: Player,
	userId: number,
	patch: { [string]: any }
): Result.Result<SharedAtoms.TSoundSettingsData>
	local normalizedPatch = Try(self.Validator:ValidatePatch(patch))
	local currentSettings = self.SyncService:GetSettingsReadOnly(userId)
		or self.PersistenceService:LoadSettings(player)
		or SharedAtoms.CloneSettings(nil)

	local nextSoundSettings = SharedAtoms.CloneSoundSettings(currentSettings.Sound)
	for key, value in normalizedPatch do
		nextSoundSettings[key] = value
	end

	local nextSettings = {
		Sound = nextSoundSettings,
	}

	Try(self.PersistenceService:SaveSettings(player, nextSettings))
	self.SyncService:SetSettings(userId, nextSettings)

	return Ok(SharedAtoms.CloneSoundSettings(nextSoundSettings))
end

return UpdateSoundSettings
