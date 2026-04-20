--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Charm = require(ReplicatedStorage.Packages.Charm)
local Registry = require(ReplicatedStorage.Utilities.Registry)

local SettingsSyncClient = require(script.Parent.Infrastructure.SettingsSyncClient)

local SettingsController = Knit.CreateController({
	Name = "SettingsController",
})

function SettingsController:KnitInit()
	local registry = Registry.new("Client")
	self.Registry = registry

	self.SyncClient = SettingsSyncClient.new()
	registry:Register("SettingsSyncClient", self.SyncClient, "Infrastructure")

	registry:InitAll()
end

function SettingsController:KnitStart()
	local registry = self.Registry

	self.SettingsContext = Knit.GetService("SettingsContext")
	self.SoundController = Knit.GetController("SoundController")

	registry:Register("SettingsContext", self.SettingsContext)
	registry:Register("SoundController", self.SoundController)
	registry:StartOrdered({ "Infrastructure" })

	self:_ConnectSoundSettings()

	task.delay(0.3, function()
		self:RequestSettingsState()
	end)
end

function SettingsController:_ConnectSoundSettings()
	local settingsAtom = self.SyncClient:GetSettingsAtom()

	self:_ApplySoundSettings(settingsAtom().Sound)

	self._SettingsCleanup = Charm.subscribe(function()
		return settingsAtom().Sound
	end, function(soundSettings)
		self:_ApplySoundSettings(soundSettings)
	end)
end

function SettingsController:_ApplySoundSettings(soundSettings: { [string]: any })
	local soundController = self.SoundController
	if not soundController or not soundSettings then
		return
	end

	soundController:SetVolume("Master", soundSettings.MasterVolume, 0.3)
	soundController:SetVolume("Music", soundSettings.MusicVolume, 0.3)
	soundController:SetVolume("SFX", soundSettings.SfxVolume, 0.3)
	soundController:SetVolume("UI", soundSettings.UiVolume, 0.3)
	soundController:SetVolume("Ambient", soundSettings.AmbientVolume, 0.3)
	soundController:SetEnabled(soundSettings.Enabled)
end

function SettingsController:GetSettingsAtom()
	return self.SyncClient:GetSettingsAtom()
end

function SettingsController:RequestSettingsState()
	return self.SettingsContext:RequestSettingsState()
		:catch(function(err)
			warn("[SettingsController:RequestSettingsState]", err.type, err.message)
		end)
end

function SettingsController:UpdateSoundSettings(patch: { [string]: any })
	return self.SettingsContext:UpdateSoundSettings(patch)
		:catch(function(err)
			warn("[SettingsController:UpdateSoundSettings]", err.type, err.message)
		end)
end

function SettingsController:Destroy()
	if self._SettingsCleanup then
		self._SettingsCleanup()
		self._SettingsCleanup = nil
	end
end

return SettingsController
