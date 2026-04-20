--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charm = require(ReplicatedStorage.Packages.Charm)

export type TSoundSettingsData = {
	MasterVolume: number,
	MusicVolume: number,
	SfxVolume: number,
	UiVolume: number,
	AmbientVolume: number,
	Enabled: boolean,
}

export type TSettingsData = {
	Sound: TSoundSettingsData,
}

export type TPlayerSettings = {
	[number]: TSettingsData,
}

local DEFAULT_SOUND_SETTINGS: TSoundSettingsData = table.freeze({
	MasterVolume = 1,
	MusicVolume = 0.8,
	SfxVolume = 1,
	UiVolume = 1,
	AmbientVolume = 0.6,
	Enabled = true,
})

local DEFAULT_SETTINGS: TSettingsData = table.freeze({
	Sound = DEFAULT_SOUND_SETTINGS,
})

local function CloneSoundSettings(settings: TSoundSettingsData?): TSoundSettingsData
	local source = settings or DEFAULT_SOUND_SETTINGS
	return {
		MasterVolume = if source.MasterVolume == nil then DEFAULT_SOUND_SETTINGS.MasterVolume else source.MasterVolume,
		MusicVolume = if source.MusicVolume == nil then DEFAULT_SOUND_SETTINGS.MusicVolume else source.MusicVolume,
		SfxVolume = if source.SfxVolume == nil then DEFAULT_SOUND_SETTINGS.SfxVolume else source.SfxVolume,
		UiVolume = if source.UiVolume == nil then DEFAULT_SOUND_SETTINGS.UiVolume else source.UiVolume,
		AmbientVolume = if source.AmbientVolume == nil then DEFAULT_SOUND_SETTINGS.AmbientVolume else source.AmbientVolume,
		Enabled = if source.Enabled == nil then DEFAULT_SOUND_SETTINGS.Enabled else source.Enabled,
	}
end

local function CloneSettings(settings: TSettingsData?): TSettingsData
	return {
		Sound = CloneSoundSettings(settings and settings.Sound or nil),
	}
end

local function CreateServerAtom()
	return Charm.atom({} :: TPlayerSettings)
end

local function CreateClientAtom()
	return Charm.atom(CloneSettings(DEFAULT_SETTINGS))
end

return table.freeze({
	DEFAULT_SOUND_SETTINGS = DEFAULT_SOUND_SETTINGS,
	DEFAULT_SETTINGS = DEFAULT_SETTINGS,
	CloneSoundSettings = CloneSoundSettings,
	CloneSettings = CloneSettings,
	CreateServerAtom = CreateServerAtom,
	CreateClientAtom = CreateClientAtom,
})
