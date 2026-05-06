--!strict

-- Modules
local Constants = require(script.Parent.Parent.Parent.Parent.Parent.Constants)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginSettings = PluginTypes.TPluginSettings
type TPluginWaypoint = PluginTypes.TPluginWaypoint
type TFolderPresetGroup = PluginTypes.TFolderPresetGroup

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
	local firstGroup = self.Settings.FolderPresetGroups[1]
	if firstGroup == nil then
		return {}
	end

	return table.clone(firstGroup.FolderNames)
end

function PluginSettingsService:GetFolderPresetGroups(): { TFolderPresetGroup }
	local groups = {}
	for _, group in self.Settings.FolderPresetGroups do
		table.insert(groups, {
			Label = group.Label,
			FolderNames = table.clone(group.FolderNames),
			Includes = table.clone(group.Includes),
		})
	end

	return groups
end

function PluginSettingsService:GetRecentAssets(): { string }
	return table.clone(self.Settings.RecentAssets)
end

function PluginSettingsService:GetSectionExpansionById(): { [string]: boolean }
	return table.clone(self.Settings.SectionExpansionById)
end

function PluginSettingsService:GetWaypoints(): { TPluginWaypoint }
	return table.clone(self.Settings.Waypoints)
end

function PluginSettingsService:GetSectionExpanded(sectionId: string): boolean
	local value = self.Settings.SectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

function PluginSettingsService:SetFolderPresets(presetNames: { string })
	self.Settings.FolderPresetGroups = self:_NormalizeFolderPresetGroups({
		{
			Label = Constants.DefaultFolderPresetGroupLabel,
			FolderNames = presetNames,
			Includes = {},
		},
	})
	self.Settings.FolderPresets = table.clone(self.Settings.FolderPresetGroups[1].FolderNames)
	self:_SaveSettings()
end

function PluginSettingsService:SetFolderPresetGroups(rawPresetGroups: { any }): (boolean, string)
	local normalizedGroups, errorMessage = self:_NormalizeFolderPresetGroups(rawPresetGroups)
	if errorMessage ~= nil then
		return false, errorMessage
	end

	self.Settings.FolderPresetGroups = normalizedGroups
	self.Settings.FolderPresets = table.clone(normalizedGroups[1].FolderNames)
	self:_SaveSettings()
	return true, "Updated folder preset groups."
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

function PluginSettingsService:SetWaypoints(waypoints: { TPluginWaypoint })
	self.Settings.Waypoints = self:_NormalizeWaypoints(waypoints)
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

	if type(rawSettings.FolderPresetGroups) == "table" then
		local normalizedGroups, normalizeError = self:_NormalizeFolderPresetGroups(rawSettings.FolderPresetGroups)
		if normalizeError == nil then
			loadedSettings.FolderPresetGroups = normalizedGroups
			loadedSettings.FolderPresets = table.clone(normalizedGroups[1].FolderNames)
		end
	elseif type(rawSettings.FolderPresets) == "table" then
		local normalizedPresetNames = self:_NormalizePresetNames(rawSettings.FolderPresets)
		loadedSettings.FolderPresetGroups = {
			{
				Label = Constants.DefaultFolderPresetGroupLabel,
				FolderNames = normalizedPresetNames,
				Includes = {},
			},
		}
		loadedSettings.FolderPresets = table.clone(normalizedPresetNames)
	end

	if type(rawSettings.RecentAssets) == "table" then
		loadedSettings.RecentAssets = self:_NormalizeRecentAssets(rawSettings.RecentAssets)
	end

	if type(rawSettings.SectionExpansionById) == "table" then
		loadedSettings.SectionExpansionById = self:_NormalizeSectionExpansionById(rawSettings.SectionExpansionById)
	end

	if type(rawSettings.Waypoints) == "table" then
		loadedSettings.Waypoints = self:_NormalizeWaypoints(rawSettings.Waypoints)
	end

	return loadedSettings
end

function PluginSettingsService:_SaveSettings()
	self.Plugin:SetSetting(SETTINGS_KEY, self.Settings)
end

function PluginSettingsService:_CreateDefaultSettings(): TPluginSettings
	local defaultFolderPresetGroup = {
		Label = Constants.DefaultFolderPresetGroupLabel,
		FolderNames = table.clone(Constants.DefaultFolderPresets),
		Includes = {},
	}

	return {
		AssetRootName = Constants.AssetRootName,
		FolderPresets = table.clone(defaultFolderPresetGroup.FolderNames),
		FolderPresetGroups = { defaultFolderPresetGroup },
		RecentAssets = {},
		SectionExpansionById = {},
		Waypoints = {},
	}
end

function PluginSettingsService:_NormalizeFolderPresetGroups(rawPresetGroups: { any }): ({ TFolderPresetGroup }, string?)
	local normalizedPresetGroups: { TFolderPresetGroup } = {}
	local seenLabels = {}

	for _, rawPresetGroup in rawPresetGroups do
		if type(rawPresetGroup) == "table" then
			local rawLabel = rawPresetGroup.Label
			local rawFolderNames = rawPresetGroup.FolderNames
			local rawIncludes = rawPresetGroup.Includes
			if type(rawLabel) == "string" and type(rawFolderNames) == "table" then
				local label = string.gsub(rawLabel, "^%s*(.-)%s*$", "%1")
				if label ~= "" and not seenLabels[label] then
					seenLabels[label] = true
					table.insert(normalizedPresetGroups, {
						Label = label,
						FolderNames = self:_NormalizePresetNames(rawFolderNames),
						Includes = self:_NormalizeIncludes(rawIncludes),
					})
				end
			end
		end
	end

	if #normalizedPresetGroups == 0 then
		normalizedPresetGroups = {
			{
				Label = Constants.DefaultFolderPresetGroupLabel,
				FolderNames = table.clone(Constants.DefaultFolderPresets),
				Includes = {},
			},
		}
	end

	local cycleError = self:_ValidatePresetIncludes(normalizedPresetGroups)
	if cycleError ~= nil then
		return normalizedPresetGroups, cycleError
	end

	return normalizedPresetGroups, nil
end

function PluginSettingsService:_ValidatePresetIncludes(groups: { TFolderPresetGroup }): string?
	local groupByLabel = {}
	for _, group in groups do
		groupByLabel[group.Label] = group
	end

	local visiting = {}
	local visited = {}
	local maxDepth = Constants.MaxFolderPresetIncludeDepth

	local function walk(label: string, depth: number): string?
		if depth > maxDepth then
			return string.format("Preset include depth exceeded max depth of %d at '%s'.", maxDepth, label)
		end

		if visiting[label] then
			return "Preset includes contain a cycle."
		end

		if visited[label] then
			return nil
		end

		local group = groupByLabel[label]
		if group == nil then
			return "Preset includes reference a missing preset label: " .. label .. "."
		end

		visiting[label] = true
		for _, includeLabel in group.Includes do
			local includeError = walk(includeLabel, depth + 1)
			if includeError ~= nil then
				return includeError
			end
		end
		visiting[label] = nil
		visited[label] = true
		return nil
	end

	for _, group in groups do
		local errorMessage = walk(group.Label, 1)
		if errorMessage ~= nil then
			return errorMessage
		end
	end

	return nil
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

	return presetNames
end

function PluginSettingsService:_NormalizeIncludes(rawIncludes: any): { string }
	if type(rawIncludes) ~= "table" then
		return {}
	end

	return self:_NormalizePresetNames(rawIncludes)
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

function PluginSettingsService:_NormalizeWaypoints(rawWaypoints: { any }): { TPluginWaypoint }
	local normalizedWaypoints: { TPluginWaypoint } = {}

	for _, rawWaypoint in rawWaypoints do
		if type(rawWaypoint) == "table" then
			local rawName = rawWaypoint.Name
			local rawComponents = rawWaypoint.CameraCFrameComponents
			if type(rawName) == "string" and type(rawComponents) == "table" then
				local name = string.gsub(rawName, "^%s*(.-)%s*$", "%1")
				if name ~= "" then
					local components = {}
					local isValid = true

					for index = 1, 12 do
						local value = rawComponents[index]
						if type(value) ~= "number" then
							isValid = false
							break
						end

						components[index] = value
					end

					if isValid then
						table.insert(normalizedWaypoints, {
							Name = name,
							CameraCFrameComponents = components,
						})

						if #normalizedWaypoints >= Constants.MaxWaypoints then
							break
						end
					end
				end
			end
		end
	end

	return normalizedWaypoints
end

return PluginSettingsService
