--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)

export type TSettingsState = {
	PresetText: string,
	FolderPresets: { string },
	SectionExpansionById: { [string]: boolean },
}

local settingsAtom = Charm.atom({
	PresetText = "",
	FolderPresets = {},
	SectionExpansionById = {},
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
		SectionExpansionById = state.SectionExpansionById,
	})
end

function SettingsAtom.SetFolderPresets(folderPresets: { string })
	local state = settingsAtom()
	settingsAtom({
		PresetText = state.PresetText,
		FolderPresets = folderPresets,
		SectionExpansionById = state.SectionExpansionById,
	})
end

function SettingsAtom.SetSectionExpansionById(sectionExpansionById: { [string]: boolean })
	local state = settingsAtom()
	settingsAtom({
		PresetText = state.PresetText,
		FolderPresets = state.FolderPresets,
		SectionExpansionById = table.clone(sectionExpansionById),
	})
end

function SettingsAtom.SetSectionExpanded(sectionId: string, isExpanded: boolean)
	local state = settingsAtom()
	local sectionExpansionById = table.clone(state.SectionExpansionById)
	sectionExpansionById[sectionId] = isExpanded
	settingsAtom({
		PresetText = state.PresetText,
		FolderPresets = state.FolderPresets,
		SectionExpansionById = sectionExpansionById,
	})
end

return SettingsAtom
