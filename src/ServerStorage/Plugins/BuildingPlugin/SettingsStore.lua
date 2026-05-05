--!strict

local Constants = require(script.Parent.Constants)

export type TSectionState = {
	Library: boolean,
	Folders: boolean,
	Selection: boolean,
	Properties: boolean,
	Settings: boolean,
}

export type TPluginSettings = {
	AssetRootName: string,
	FolderPresets: { string },
	SectionState: TSectionState,
	RecentAssets: { string },
}

local SettingsStore = {}
SettingsStore.__index = SettingsStore

local SETTINGS_KEY = "BuildingPlugin.Settings"
local OPEN_KEY = "BuildingPlugin.IsOpen"

function SettingsStore.new(pluginInstance: Plugin)
	local self = setmetatable({}, SettingsStore)
	self.Plugin = pluginInstance
	self.Settings = self:_LoadSettings()
	return self
end

function SettingsStore:GetSettings(): TPluginSettings
	return self.Settings
end

function SettingsStore:GetAssetRootName(): string
	return self.Settings.AssetRootName
end

function SettingsStore:GetFolderPresets(): { string }
	return table.clone(self.Settings.FolderPresets)
end

function SettingsStore:GetSectionState(): TSectionState
	return table.clone(self.Settings.SectionState)
end

function SettingsStore:GetRecentAssets(): { string }
	return table.clone(self.Settings.RecentAssets)
end

function SettingsStore:SetFolderPresets(presetNames: { string })
	self.Settings.FolderPresets = self:_NormalizePresetNames(presetNames)
	self:_SaveSettings()
end

function SettingsStore:SetSectionState(sectionName: string, isOpen: boolean)
	local nextSectionState = table.clone(self.Settings.SectionState)

	if sectionName == "Library" then
		nextSectionState.Library = isOpen
	elseif sectionName == "Folders" then
		nextSectionState.Folders = isOpen
	elseif sectionName == "Selection" then
		nextSectionState.Selection = isOpen
	elseif sectionName == "Properties" then
		nextSectionState.Properties = isOpen
	elseif sectionName == "Settings" then
		nextSectionState.Settings = isOpen
	end

	self.Settings.SectionState = nextSectionState
	self:_SaveSettings()
end

function SettingsStore:PushRecentAsset(assetPath: string)
	local recentAssets = self:GetRecentAssets()
	local deduped = {}
	local seenAssets = { [assetPath] = true }

	table.insert(deduped, assetPath)

	for _, recentAssetPath in recentAssets do
		if (not seenAssets[recentAssetPath]) and (#deduped < Constants.MaxRecentAssets) then
			seenAssets[recentAssetPath] = true
			table.insert(deduped, recentAssetPath)
		end
	end

	self.Settings.RecentAssets = deduped
	self:_SaveSettings()
end

function SettingsStore:GetIsOpen(): boolean
	local storedValue = self.Plugin:GetSetting(OPEN_KEY)
	return storedValue == true
end

function SettingsStore:SetIsOpen(isOpen: boolean)
	self.Plugin:SetSetting(OPEN_KEY, isOpen)
end

function SettingsStore:_LoadSettings(): TPluginSettings
	local storedValue = self.Plugin:GetSetting(SETTINGS_KEY)

	if type(storedValue) ~= "table" then
		return self:_CreateDefaultSettings()
	end

	local rawSettings = storedValue :: { [string]: any }
	local loadedSettings = self:_CreateDefaultSettings()

	if type(rawSettings.AssetRootName) == "string" and rawSettings.AssetRootName ~= "" then
		loadedSettings.AssetRootName = rawSettings.AssetRootName
	end

	if type(rawSettings.FolderPresets) == "table" then
		loadedSettings.FolderPresets = self:_NormalizePresetNames(rawSettings.FolderPresets)
	end

	if type(rawSettings.RecentAssets) == "table" then
		loadedSettings.RecentAssets = self:_NormalizeRecentAssets(rawSettings.RecentAssets)
	end

	if type(rawSettings.SectionState) == "table" then
		loadedSettings.SectionState = self:_NormalizeSectionState(rawSettings.SectionState)
	end

	return loadedSettings
end

function SettingsStore:_SaveSettings()
	self.Plugin:SetSetting(SETTINGS_KEY, self.Settings)
end

function SettingsStore:_CreateDefaultSettings(): TPluginSettings
	return {
		AssetRootName = Constants.AssetRootName,
		FolderPresets = table.clone(Constants.DefaultFolderPresets),
		SectionState = table.clone(Constants.DefaultSectionState),
		RecentAssets = {},
	}
end

function SettingsStore:_NormalizePresetNames(rawPresetNames: { any }): { string }
	local presetNames = {}
	local seenPresetNames = {}

	for _, rawPresetName in rawPresetNames do
		if type(rawPresetName) == "string" then
			local normalizedPresetName = string.gsub(rawPresetName, "^%s*(.-)%s*$", "%1")
			if (normalizedPresetName ~= "") and (not seenPresetNames[normalizedPresetName]) then
				seenPresetNames[normalizedPresetName] = true
				table.insert(presetNames, normalizedPresetName)
			end
		end
	end

	if #presetNames == 0 then
		return table.clone(Constants.DefaultFolderPresets)
	end

	return presetNames
end

function SettingsStore:_NormalizeRecentAssets(rawRecentAssets: { any }): { string }
	local recentAssets = {}
	local seenAssets = {}

	for _, rawAssetPath in rawRecentAssets do
		if type(rawAssetPath) == "string" and (rawAssetPath ~= "") and (not seenAssets[rawAssetPath]) then
			seenAssets[rawAssetPath] = true
			table.insert(recentAssets, rawAssetPath)

			if #recentAssets >= Constants.MaxRecentAssets then
				break
			end
		end
	end

	return recentAssets
end

function SettingsStore:_NormalizeSectionState(rawSectionState: { [string]: any }): TSectionState
	local defaultSectionState = Constants.DefaultSectionState

	return {
		Library = if type(rawSectionState.Library) == "boolean" then rawSectionState.Library else defaultSectionState.Library,
		Folders = if type(rawSectionState.Folders) == "boolean" then rawSectionState.Folders else defaultSectionState.Folders,
		Selection = if type(rawSectionState.Selection) == "boolean" then rawSectionState.Selection else defaultSectionState.Selection,
		Properties = if type(rawSectionState.Properties) == "boolean" then rawSectionState.Properties else defaultSectionState.Properties,
		Settings = if type(rawSectionState.Settings) == "boolean" then rawSectionState.Settings else defaultSectionState.Settings,
	}
end

return SettingsStore
