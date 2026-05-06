--!strict

local OrganizationViewModel = {}

function OrganizationViewModel.FromState(organizationState, settingsState)
	local presetLabels = {}
	for _, presetGroup in settingsState.FolderPresetGroups do
		table.insert(presetLabels, presetGroup.Label)
	end

	local instructionText = table.concat({
		"1) Select exactly one parent instance in Explorer.",
		"2) Pick an object name from direct children or type one manually.",
		"3) Click Group Objects Into Folder.",
	}, "\n")

	local nameSelectorHelpText = if #organizationState.AvailableChildNames == 0
		then "No direct-child names available from current selection."
		else "Object Name selector is populated from direct child names on the selected parent."

	return table.freeze({
		MatchObjectName = organizationState.MatchObjectName,
		DestinationFolderName = organizationState.DestinationFolderName,
		SelectedChildName = organizationState.SelectedChildName,
		AvailableChildNames = organizationState.AvailableChildNames,
		SelectedPresetLabel = organizationState.SelectedPresetLabel,
		PresetLabels = presetLabels,
		InstructionText = instructionText,
		NameSelectorHelpText = nameSelectorHelpText,
		MatchNameHelpText = "Object Name To Find: direct child name to match under selected parent.",
		DestinationNameHelpText = "Folder Name To Create/Use: destination folder for matched objects.",
	})
end

return OrganizationViewModel
