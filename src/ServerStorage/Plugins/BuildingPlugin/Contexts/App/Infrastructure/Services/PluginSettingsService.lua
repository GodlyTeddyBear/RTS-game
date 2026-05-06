--!strict

-- Modules
local Constants = require(script.Parent.Parent.Parent.Parent.Parent.Constants)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginSettings = PluginTypes.TPluginSettings

local SETTINGS_KEY = "BuildingPlugin.Settings"
local OPEN_KEY = "BuildingPlugin.IsOpen"

local PluginSettingsService = {}
PluginSettingsService.__index = PluginSettingsService

function PluginSettingsService.new(pluginInstance: Plugin)
	local self = setmetatable({}, PluginSettingsService)
	self.Plugin = pluginInstance
	self.Settings = self:_LoadSettings()
	return self
end

function PluginSettingsService:GetSettings(): TPluginSettings
	return self.Settings
end

function PluginSettingsService:GetAssetRootName(): string
	return self.Settings.AssetRootName
end

function PluginSettingsService:GetFolderPresets(): { string }
	return table.clone(self.Settings.FolderPresets)
end

function PluginSettingsService:GetRecentAssets(): { string }
	return table.clone(self.Settings.RecentAssets)
end

function PluginSettingsService:GetSectionExpansionById(): { [string]: boolean }
	return table.clone(self.Settings.SectionExpansionById)
end

function PluginSettingsService:GetSectionExpanded(sectionId: string): boolean
	local value = self.Settings.SectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

function PluginSettingsService:SetFolderPresets(presetNames: { string })
	self.Settings.FolderPresets = self:_NormalizePresetNames(presetNames)
	self:_SaveSettings()
end

function PluginSettingsService:SetSectionExpanded(sectionId: string, isExpanded: boolean)
	self.Settings.SectionExpansionById[sectionId] = isExpanded
	self:_SaveSettings()
end

function PluginSettingsService:SetSectionsExpanded(sectionIds: { string }, isExpanded: boolean)
	for _, sectionId in sectionIds do
		self.Settings.SectionExpansionById[sectionId] = isExpanded
	end

	self:_SaveSettings()
end

function PluginSettingsService:PushRecentAsset(assetPath: string)
	local recentAssets = self:GetRecentAssets()
	local deduped = { assetPath }
	local seenAssets = { [assetPath] = true }

	for _, recentAssetPath in recentAssets do
		if (not seenAssets[recentAssetPath]) and (#deduped < Constants.MaxRecentAssets) then
			seenAssets[recentAssetPath] = true
			table.insert(deduped, recentAssetPath)
		end
	end

	self.Settings.RecentAssets = deduped
	self:_SaveSettings()
end

function PluginSettingsService:RemoveRecentAsset(assetPath: string)
	local remainingRecentAssets = {}

	for _, recentAssetPath in self.Settings.RecentAssets do
		if recentAssetPath ~= assetPath then
			table.insert(remainingRecentAssets, recentAssetPath)
		end
	end

	self.Settings.RecentAssets = remainingRecentAssets
	self:_SaveSettings()
end

function PluginSettingsService:GetIsOpen(): boolean
	return self.Plugin:GetSetting(OPEN_KEY) == true
end

function PluginSettingsService:SetIsOpen(isOpen: boolean)
	self.Plugin:SetSetting(OPEN_KEY, isOpen)
end

function PluginSettingsService:_LoadSettings(): TPluginSettings
	local storedValue = self.Plugin:GetSetting(SETTINGS_KEY)
	local loadedSettings = self:_CreateDefaultSettings()

	if type(storedValue) ~= "table" then
		return loadedSettings
	end

	local rawSettings = storedValue :: { [string]: any }

	if type(rawSettings.AssetRootName) == "string" and rawSettings.AssetRootName ~= "" then
		loadedSettings.AssetRootName = rawSettings.AssetRootName
	end

	if type(rawSettings.FolderPresets) == "table" then
		loadedSettings.FolderPresets = self:_NormalizePresetNames(rawSettings.FolderPresets)
	end

	if type(rawSettings.RecentAssets) == "table" then
		loadedSettings.RecentAssets = self:_NormalizeRecentAssets(rawSettings.RecentAssets)
	end

	if type(rawSettings.SectionExpansionById) == "table" then
		loadedSettings.SectionExpansionById = self:_NormalizeSectionExpansionById(rawSettings.SectionExpansionById)
	end

	return loadedSettings
end

function PluginSettingsService:_SaveSettings()
	self.Plugin:SetSetting(SETTINGS_KEY, self.Settings)
end

function PluginSettingsService:_CreateDefaultSettings(): TPluginSettings
	return {
		AssetRootName = Constants.AssetRootName,
		FolderPresets = table.clone(Constants.DefaultFolderPresets),
		RecentAssets = {},
		SectionExpansionById = {},
	}
end

function PluginSettingsService:_NormalizePresetNames(rawPresetNames: { any }): { string }
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

function PluginSettingsService:_NormalizeRecentAssets(rawRecentAssets: { any }): { string }
	local recentAssets = {}
	local seenAssets = {}

	for _, rawAssetPath in rawRecentAssets do
		if type(rawAssetPath) == "string" and rawAssetPath ~= "" and not seenAssets[rawAssetPath] then
			seenAssets[rawAssetPath] = true
			table.insert(recentAssets, rawAssetPath)

			if #recentAssets >= Constants.MaxRecentAssets then
				break
			end
		end
	end

	return recentAssets
end

function PluginSettingsService:_NormalizeSectionExpansionById(rawSectionExpansionById: { [string]: any }): { [string]: boolean }
	local sectionExpansionById: { [string]: boolean } = {}

	for key, value in rawSectionExpansionById do
		if type(key) == "string" and key ~= "" and type(value) == "boolean" then
			sectionExpansionById[key] = value
		end
	end

	return sectionExpansionById
end

return PluginSettingsService
