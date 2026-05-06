--!strict

local Constants = require(script.Parent.Parent.Parent.Parent.Parent.Constants)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TPluginActionResult = PluginTypes.TPluginActionResult
type TFolderPresetGroup = PluginTypes.TFolderPresetGroup

local OrganizationService = {}
OrganizationService.__index = OrganizationService

function OrganizationService.new(historyAdapter, selectionService, settingsService)
	local self = setmetatable({}, OrganizationService)
	self.History = historyAdapter
	self.Selection = selectionService
	self.Settings = settingsService
	return self
end

function OrganizationService:GroupChildrenByName(matchObjectName: string, destinationFolderName: string): TPluginActionResult
	local normalizedMatchObjectName = string.gsub(matchObjectName, "^%s*(.-)%s*$", "%1")
	if normalizedMatchObjectName == "" then
		return self:_CreateResult(false, 0, 0, "Enter an object name to find before grouping by name.")
	end

	local normalizedFolderName = string.gsub(destinationFolderName, "^%s*(.-)%s*$", "%1")
	if normalizedFolderName == "" then
		return self:_CreateResult(false, 0, 0, "Enter a folder name before grouping by name.")
	end

	local selectedParent, selectionError = self:_GetSelectedParent()
	if selectedParent == nil then
		return self:_CreateResult(false, 0, 0, selectionError)
	end

	local destinationFolder = selectedParent:FindFirstChild(normalizedFolderName)
	if destinationFolder ~= nil and not destinationFolder:IsA("Folder") then
		return self:_CreateResult(false, 0, 0, "A non-folder instance already uses that destination name.")
	end

	local groupedChildren = {}
	for _, child in selectedParent:GetChildren() do
		if child.Name == normalizedMatchObjectName and child ~= destinationFolder then
			table.insert(groupedChildren, child)
		end
	end

	if #groupedChildren == 0 then
		return self:_CreateResult(false, 0, 0, "No direct children matched object name '" .. normalizedMatchObjectName .. "'.")
	end

	local folderToUse = destinationFolder
	local createdFolder = false
	self.History:Run("Organization Group By Name", function()
		if folderToUse == nil then
			folderToUse = Instance.new("Folder")
			folderToUse.Name = normalizedFolderName
			folderToUse.Parent = selectedParent
			createdFolder = true
		end

		for _, child in groupedChildren do
			if child.Parent == selectedParent then
				child.Parent = folderToUse
			end
		end
	end)

	if folderToUse ~= nil then
		self.Selection.SetSelection({ folderToUse })
	end

	local message = if createdFolder
		then (
			"Grouped "
			.. tostring(#groupedChildren)
			.. " objects named "
			.. normalizedMatchObjectName
			.. " into new folder "
			.. normalizedFolderName
			.. "."
		)
		else (
			"Grouped "
			.. tostring(#groupedChildren)
			.. " objects named "
			.. normalizedMatchObjectName
			.. " into existing folder "
			.. normalizedFolderName
			.. "."
		)

	return self:_CreateResult(true, #groupedChildren, 0, message)
end

function OrganizationService:CreatePresetFolders(presetLabel: string): TPluginActionResult
	local normalizedPresetLabel = string.gsub(presetLabel, "^%s*(.-)%s*$", "%1")
	if normalizedPresetLabel == "" then
		return self:_CreateResult(false, 0, 0, "Select a preset group before creating folders.")
	end

	local selectedParent, selectionError = self:_GetSelectedParent()
	if selectedParent == nil then
		return self:_CreateResult(false, 0, 0, selectionError)
	end

	local presetGroups = self.Settings:GetFolderPresetGroups()
	local groupByLabel = {}
	for _, presetGroup in presetGroups do
		groupByLabel[presetGroup.Label] = presetGroup
	end

	local rootGroup = groupByLabel[normalizedPresetLabel]
	if rootGroup == nil then
		return self:_CreateResult(false, 0, 0, "Selected preset group does not exist.")
	end

	local validationError = self:_ValidatePresetGroups(presetGroups)
	if validationError ~= nil then
		return self:_CreateResult(false, 0, 0, validationError)
	end

	local changedCount = 0
	local skippedCount = 0

	local function ensureFolder(parentInstance: Instance, folderName: string): Folder?
		local existing = parentInstance:FindFirstChild(folderName)
		if existing ~= nil then
			if existing:IsA("Folder") then
				skippedCount += 1
				return existing
			end

			return nil
		end

		local folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = parentInstance
		changedCount += 1
		return folder
	end

	local function applyGroup(parentInstance: Instance, group: TFolderPresetGroup, depth: number): boolean
		if depth > Constants.MaxFolderPresetIncludeDepth then
			return false
		end

		for _, folderName in group.FolderNames do
			if ensureFolder(parentInstance, folderName) == nil then
				return false
			end
		end

		for _, includeLabel in group.Includes do
			local includeGroup = groupByLabel[includeLabel]
			if includeGroup ~= nil then
				local includeParent = ensureFolder(parentInstance, includeLabel)
				if includeParent == nil then
					return false
				end

				if not applyGroup(includeParent, includeGroup, depth + 1) then
					return false
				end
			end
		end

		return true
	end

	local applySucceeded = false
	self.History:Run("Organization Create Preset Folders", function()
		applySucceeded = applyGroup(selectedParent, rootGroup, 1)
	end)

	if not applySucceeded then
		return self:_CreateResult(false, changedCount, skippedCount, "Failed to create preset folders due to invalid hierarchy state.")
	end

	return self:_CreateResult(
		true,
		changedCount,
		skippedCount,
		"Applied preset group " .. normalizedPresetLabel .. " to selected parent."
	)
end

function OrganizationService:_ValidatePresetGroups(groups: { TFolderPresetGroup }): string?
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

function OrganizationService:_GetSelectedParent(): (Instance?, string)
	local selection = self.Selection.GetSelection()
	if #selection ~= 1 then
		return nil, "Select exactly one parent instance before running organization actions."
	end

	local selectedParent = selection[1]
	if selectedParent == nil then
		return nil, "Selected parent is unavailable."
	end

	if selectedParent.Parent == nil then
		return nil, "Selected parent must be in the data model."
	end

	return selectedParent, ""
end

function OrganizationService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string): TPluginActionResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
		Path = nil,
	}
end

return OrganizationService
