--!strict
local SharedAtoms = require(game:GetService("ReplicatedStorage").Contexts.Settings.Sync.SharedAtoms)

export type TSoundControlRow = {
	Key: string,
	Label: string,
	Value: number,
	DisplayValue: string,
}

export type TSettingsViewData = {
	SoundEnabled: boolean,
	SoundRows: { TSoundControlRow },
}

local SOUND_ROW_DEFINITIONS = table.freeze({
	{ Key = "MasterVolume", Label = "Master" },
	{ Key = "MusicVolume", Label = "Music" },
	{ Key = "SfxVolume", Label = "SFX" },
	{ Key = "UiVolume", Label = "UI" },
	{ Key = "AmbientVolume", Label = "Ambient" },
})

local SettingsViewModel = {}

local function _FormatPercent(value: number): string
	return tostring(math.round(value * 100)) .. "%"
end

function SettingsViewModel.fromSettings(settings: SharedAtoms.TSettingsData): TSettingsViewData
	local sound = settings.Sound
	local rows = {}

	for index, definition in SOUND_ROW_DEFINITIONS do
		local value = sound[definition.Key] or 0
		rows[index] = table.freeze({
			Key = definition.Key,
			Label = definition.Label,
			Value = value,
			DisplayValue = _FormatPercent(value),
		})
	end

	return table.freeze({
		SoundEnabled = sound.Enabled,
		SoundRows = table.freeze(rows),
	})
end

return SettingsViewModel
