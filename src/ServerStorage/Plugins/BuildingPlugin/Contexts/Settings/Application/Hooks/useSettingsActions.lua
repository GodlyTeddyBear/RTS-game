--!strict

local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)
local SettingsAtom = require(script.Parent.Parent.Parent.Infrastructure.SettingsAtom)

local function parsePresetSettings(rawText: string): { string }
	local presetNames = {}

	for presetName in string.gmatch(rawText, "([^,]+)") do
		table.insert(presetNames, presetName)
	end

	return presetNames
end

local function useSettingsActions()
	local services = usePluginServices()

	local function refreshSettings()
		local folderPresets = services.Settings:GetFolderPresets()
		SettingsAtom.SetFolderPresets(folderPresets)
		SettingsAtom.SetPresetText(table.concat(folderPresets, ", "))
		SettingsAtom.SetSectionExpansionById(services.Settings:GetSectionExpansionById())
	end

	return {
		RefreshSettings = refreshSettings,
		SetPresetText = function(presetText: string)
			SettingsAtom.SetPresetText(presetText)
		end,
		SavePresets = function()
			services.Settings:SetFolderPresets(parsePresetSettings(SettingsAtom.GetState().PresetText))
			refreshSettings()
			AppAtom.SetStatus("Updated folder presets.", "Success")
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
