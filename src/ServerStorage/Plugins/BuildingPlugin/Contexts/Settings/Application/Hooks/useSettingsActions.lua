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
	}
end

return useSettingsActions
