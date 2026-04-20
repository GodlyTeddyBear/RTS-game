--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local SharedAtoms = require(ReplicatedStorage.Contexts.Settings.Sync.SharedAtoms)

local Ok = Result.Ok
local Ensure = Result.Ensure

local SettingsPersistenceService = {}
SettingsPersistenceService.__index = SettingsPersistenceService

function SettingsPersistenceService.new()
	return setmetatable({}, SettingsPersistenceService)
end

function SettingsPersistenceService:Init(registry: any, _name: string)
	self.ProfileManager = registry:Get("ProfileManager")
end

function SettingsPersistenceService:LoadSettings(player: Player): SharedAtoms.TSettingsData?
	local data = self.ProfileManager:GetData(player)
	if not data then
		return nil
	end

	data.Settings = data.Settings or {}
	data.Settings.Sound = SharedAtoms.CloneSoundSettings(data.Settings.Sound)

	return SharedAtoms.CloneSettings(data.Settings)
end

function SettingsPersistenceService:SaveSettings(player: Player, settings: SharedAtoms.TSettingsData): Result.Result<boolean>
	local data = self.ProfileManager:GetData(player)
	Ensure(data, "PersistenceFailed", "No profile data is available.", { userId = player.UserId })

	data.Settings = data.Settings or {}
	data.Settings.Sound = SharedAtoms.CloneSoundSettings(settings.Sound)

	return Ok(true)
end

return SettingsPersistenceService
