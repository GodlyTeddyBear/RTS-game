--!strict

local SettingsViewModel = {}

function SettingsViewModel.FromState(state)
	local groupLabels = {}
	local groupByLabel = {}
	for _, group in state.FolderPresetGroups do
		table.insert(groupLabels, group.Label)
		groupByLabel[group.Label] = group
	end

	local selectedGroup = nil
	if state.SelectedPresetGroupLabel ~= nil then
		for _, group in state.FolderPresetGroups do
			if group.Label == state.SelectedPresetGroupLabel then
				selectedGroup = group
				break
			end
		end
	end

	local previewText = if #groupLabels == 0 then "No preset groups configured." else table.concat(groupLabels, ", ")
	local selectedGroupLabel = if selectedGroup ~= nil then selectedGroup.Label else state.SelectedPresetGroupLabel
	local helpText = table.concat({
		"Label: preset group name used in dropdowns and nested includes.",
		"Folder Names: comma-separated folders created directly under the target parent.",
		"Includes: comma-separated preset labels that create nested group folders.",
	}, "\n")
	local exampleText = table.concat({
		"Example:",
		"Label = Organization",
		"Folder Names = Props, Decor",
		"Includes = Misc",
		"Result Preview:",
		"Organization",
		"  Props",
		"  Decor",
		"  Misc",
	}, "\n")

	local function buildStructurePreview(group, depth, visited)
		local indent = string.rep("  ", depth)
		local lines = {}
		table.insert(lines, indent .. group.Label)

		for _, folderName in group.FolderNames do
			table.insert(lines, indent .. "  " .. folderName)
		end

		for _, includeLabel in group.Includes do
			local includeGroup = groupByLabel[includeLabel]
			if includeGroup == nil then
				table.insert(lines, indent .. "  [Missing include: " .. includeLabel .. "]")
			elseif visited[includeLabel] then
				table.insert(lines, indent .. "  [Cycle include: " .. includeLabel .. "]")
			else
				local nextVisited = table.clone(visited)
				nextVisited[includeLabel] = true
				local includeLines = buildStructurePreview(includeGroup, depth + 1, nextVisited)
				for _, line in includeLines do
					table.insert(lines, line)
				end
			end
		end

		return lines
	end

	local structurePreviewText = "Select a preset group to preview its structure."
	if selectedGroup ~= nil then
		local visited = { [selectedGroup.Label] = true }
		structurePreviewText = table.concat(buildStructurePreview(selectedGroup, 0, visited), "\n")
	end

	return table.freeze({
		PresetGroupLabelInput = state.PresetGroupLabelInput,
		PresetGroupFolderNamesInput = state.PresetGroupFolderNamesInput,
		PresetGroupIncludesInput = state.PresetGroupIncludesInput,
		SelectedPresetGroupLabel = selectedGroupLabel,
		GroupLabels = groupLabels,
		PreviewText = previewText,
		HelpText = helpText,
		ExampleText = exampleText,
		StructurePreviewText = structurePreviewText,
	})
end

return SettingsViewModel
