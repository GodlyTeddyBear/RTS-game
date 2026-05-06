--!strict

local SettingsViewModel = {}

function SettingsViewModel.FromState(state)
	local previewText = if #state.FolderPresets == 0
		then "No presets configured."
		else table.concat(state.FolderPresets, ", ")

	return table.freeze({
		PresetText = state.PresetText,
		PreviewText = previewText,
	})
end

return SettingsViewModel
