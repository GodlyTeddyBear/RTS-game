--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TFolderPresetGroup = PluginTypes.TFolderPresetGroup

export type TSettingsState = {
	PresetGroupLabelInput: string,
	PresetGroupFolderNamesInput: string,
	PresetGroupIncludesInput: string,
	SelectedPresetGroupLabel: string?,
	FolderPresets: { string },
	FolderPresetGroups: { TFolderPresetGroup },
	SectionExpansionById: { [string]: boolean },
	BackupSnapshotNames: { string },
	SelectedBackupSnapshotName: string?,
}

local settingsAtom = Charm.atom({
	PresetGroupLabelInput = "",
	PresetGroupFolderNamesInput = "",
	PresetGroupIncludesInput = "",
	SelectedPresetGroupLabel = nil,
	FolderPresets = {},
	FolderPresetGroups = {},
	SectionExpansionById = {},
	BackupSnapshotNames = {},
	SelectedBackupSnapshotName = nil,
} :: TSettingsState)

local SettingsAtom = {}

function SettingsAtom.GetAtom()
	return settingsAtom
end

function SettingsAtom.GetState(): TSettingsState
	return settingsAtom()
end

function SettingsAtom.SetPresetGroupLabelInput(value: string)
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = value,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetPresetGroupFolderNamesInput(value: string)
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = value,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetPresetGroupIncludesInput(value: string)
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = value,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetSelectedPresetGroupLabel(value: string?)
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = value,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetFolderPresets(folderPresets: { string })
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = folderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetFolderPresetGroups(folderPresetGroups: { TFolderPresetGroup })
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = folderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetSectionExpansionById(sectionExpansionById: { [string]: boolean })
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = table.clone(sectionExpansionById),
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetSectionExpanded(sectionId: string, isExpanded: boolean)
	local state = settingsAtom()
	local sectionExpansionById = table.clone(state.SectionExpansionById)
	sectionExpansionById[sectionId] = isExpanded
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = sectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetBackupSnapshotNames(backupSnapshotNames: { string })
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = table.clone(backupSnapshotNames),
		SelectedBackupSnapshotName = state.SelectedBackupSnapshotName,
	})
end

function SettingsAtom.SetSelectedBackupSnapshotName(value: string?)
	local state = settingsAtom()
	settingsAtom({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = state.SelectedPresetGroupLabel,
		FolderPresets = state.FolderPresets,
		FolderPresetGroups = state.FolderPresetGroups,
		SectionExpansionById = state.SectionExpansionById,
		BackupSnapshotNames = state.BackupSnapshotNames,
		SelectedBackupSnapshotName = value,
	})
end

return SettingsAtom
