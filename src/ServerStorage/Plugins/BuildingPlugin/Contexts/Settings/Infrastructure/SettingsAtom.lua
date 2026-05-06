--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type TSettingsState = {
	PresetText: string,
	FolderPresets: { string },
}

local settingsAtom = Charm.atom({
	PresetText = "",
	FolderPresets = {},
} :: TSettingsState)

local SettingsAtom = {}

function SettingsAtom.GetAtom()
	return settingsAtom
end

function SettingsAtom.GetState(): TSettingsState
	return settingsAtom()
end

function SettingsAtom.SetPresetText(presetText: string)
	local state = settingsAtom()
	settingsAtom({
		PresetText = presetText,
		FolderPresets = state.FolderPresets,
	})
end

function SettingsAtom.SetFolderPresets(folderPresets: { string })
	local state = settingsAtom()
	settingsAtom({
		PresetText = state.PresetText,
		FolderPresets = folderPresets,
	})
end

return SettingsAtom
