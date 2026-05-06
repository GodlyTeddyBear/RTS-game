--!strict

local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)
local SettingsAtom = require(script.Parent.Parent.Parent.Infrastructure.SettingsAtom)

local function parseCommaSeparatedText(rawText: string): { string }
	local values = {}

	for value in string.gmatch(rawText, "([^,]+)") do
		table.insert(values, value)
	end

	return values
end

local function useSettingsActions()
	local services = usePluginServices()

	local function refreshSettings()
		local folderPresets = services.Settings:GetFolderPresets()
		local folderPresetGroups = services.Settings:GetFolderPresetGroups()

		SettingsAtom.SetFolderPresets(folderPresets)
		SettingsAtom.SetFolderPresetGroups(folderPresetGroups)
		SettingsAtom.SetSectionExpansionById(services.Settings:GetSectionExpansionById())

		local selectedLabel = SettingsAtom.GetState().SelectedPresetGroupLabel
		if selectedLabel ~= nil then
			for _, presetGroup in folderPresetGroups do
				if presetGroup.Label == selectedLabel then
					return
				end
			end

			SettingsAtom.SetSelectedPresetGroupLabel(nil)
		end
	end

	local function savePresetGroups(nextGroups)
		local success, message = services.Settings:SetFolderPresetGroups(nextGroups)
		refreshSettings()
		AppAtom.SetStatus(message, if success then "Success" else "Error")
	end

	return {
		RefreshSettings = refreshSettings,
		SetPresetGroupLabelInput = function(value: string)
			SettingsAtom.SetPresetGroupLabelInput(value)
		end,
		SetPresetGroupFolderNamesInput = function(value: string)
			SettingsAtom.SetPresetGroupFolderNamesInput(value)
		end,
		SetPresetGroupIncludesInput = function(value: string)
			SettingsAtom.SetPresetGroupIncludesInput(value)
		end,
		SetSelectedPresetGroupLabel = function(value: string?)
			SettingsAtom.SetSelectedPresetGroupLabel(value)
		end,
		SavePresetGroup = function()
			local state = SettingsAtom.GetState()
			local label = string.gsub(state.PresetGroupLabelInput, "^%s*(.-)%s*$", "%1")
			if label == "" then
				AppAtom.SetStatus("Enter a preset group label before saving.", "Error")
				return
			end

			local groups = services.Settings:GetFolderPresetGroups()
			local nextGroups = {}
			local hasReplaced = false
			for _, group in groups do
				if group.Label == label then
					hasReplaced = true
					table.insert(nextGroups, {
						Label = label,
						FolderNames = parseCommaSeparatedText(state.PresetGroupFolderNamesInput),
						Includes = parseCommaSeparatedText(state.PresetGroupIncludesInput),
					})
				else
					table.insert(nextGroups, group)
				end
			end

			if not hasReplaced then
				table.insert(nextGroups, {
					Label = label,
					FolderNames = parseCommaSeparatedText(state.PresetGroupFolderNamesInput),
					Includes = parseCommaSeparatedText(state.PresetGroupIncludesInput),
				})
			end

			savePresetGroups(nextGroups)
		end,
		LoadSelectedPresetGroup = function()
			local state = SettingsAtom.GetState()
			local selectedLabel = state.SelectedPresetGroupLabel
			if selectedLabel == nil then
				AppAtom.SetStatus("Select a preset group to load.", "Error")
				return
			end

			for _, group in state.FolderPresetGroups do
				if group.Label == selectedLabel then
					SettingsAtom.SetPresetGroupLabelInput(group.Label)
					SettingsAtom.SetPresetGroupFolderNamesInput(table.concat(group.FolderNames, ", "))
					SettingsAtom.SetPresetGroupIncludesInput(table.concat(group.Includes, ", "))
					AppAtom.SetStatus("Loaded preset group " .. group.Label .. ".", "Success")
					return
				end
			end

			AppAtom.SetStatus("Selected preset group no longer exists.", "Error")
		end,
		DeleteSelectedPresetGroup = function()
			local state = SettingsAtom.GetState()
			local selectedLabel = state.SelectedPresetGroupLabel
			if selectedLabel == nil then
				AppAtom.SetStatus("Select a preset group before deleting.", "Error")
				return
			end

			local nextGroups = {}
			for _, group in state.FolderPresetGroups do
				if group.Label ~= selectedLabel then
					table.insert(nextGroups, group)
				end
			end

			if #nextGroups == #state.FolderPresetGroups then
				AppAtom.SetStatus("Selected preset group no longer exists.", "Error")
				return
			end

			savePresetGroups(nextGroups)
			SettingsAtom.SetSelectedPresetGroupLabel(nil)
		end,
		SetSectionExpanded = function(sectionId: string, isExpanded: boolean)
			services.Settings:SetSectionExpanded(sectionId, isExpanded)
			SettingsAtom.SetSectionExpanded(sectionId, isExpanded)
		end,
		SetSectionsExpanded = function(sectionIds: { string }, isExpanded: boolean)
			services.Settings:SetSectionsExpanded(sectionIds, isExpanded)
			local sectionExpansionById = SettingsAtom.GetState().SectionExpansionById
			local nextSectionExpansionById = table.clone(sectionExpansionById)
			for _, sectionId in sectionIds do
				nextSectionExpansionById[sectionId] = isExpanded
			end
			SettingsAtom.SetSectionExpansionById(nextSectionExpansionById)
		end,
	}
end

return useSettingsActions
