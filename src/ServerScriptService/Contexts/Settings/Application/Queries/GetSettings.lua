--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Utilities.Result)
local SharedAtoms = require(ReplicatedStorage.Contexts.Settings.Sync.SharedAtoms)

local Ok = Result.Ok

local GetSettings = {}
GetSettings.__index = GetSettings

function GetSettings.new()
	return setmetatable({}, GetSettings)
end

function GetSettings:Init(registry: any, _name: string)
	self.PersistenceService = registry:Get("SettingsPersistenceService")
	self.SyncService = registry:Get("SettingsSyncService")
end

function GetSettings:Execute(player: Player, userId: number): Result.Result<SharedAtoms.TSettingsData>
	local settings = self.SyncService:GetSettingsReadOnly(userId)
		or self.PersistenceService:LoadSettings(player)
		or SharedAtoms.CloneSettings(nil)

	return Ok(SharedAtoms.CloneSettings(settings))
end

return GetSettings
