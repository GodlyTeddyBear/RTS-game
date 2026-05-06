--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PluginTypes = require(script.Parent.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TAssetEntry = PluginTypes.TAssetEntry
type TPluginActionResult = PluginTypes.TPluginActionResult

local DELETE_FOLDER_NAME = "__Delete__"

local AssetLibraryService = {}
AssetLibraryService.__index = AssetLibraryService

function AssetLibraryService.new(settingsService, historyAdapter, selectionService)
	local self = setmetatable({}, AssetLibraryService)
	self.Settings = settingsService
	self.History = historyAdapter
	self.Selection = selectionService
	return self
end

function AssetLibraryService:GetAssetRoot(): Folder?
	local assetRoot = ReplicatedStorage:FindFirstChild(self.Settings:GetAssetRootName())
	if assetRoot and assetRoot:IsA("Folder") then
		return assetRoot
	end

	return nil
end

function AssetLibraryService:EnsureAssetRoot(): Folder
	local existingRoot = self:GetAssetRoot()
	if existingRoot ~= nil then
		return existingRoot
	end

	local assetRoot = Instance.new("Folder")
	assetRoot.Name = self.Settings:GetAssetRootName()

	self.History:Run("Create Asset Root", function()
		assetRoot.Parent = ReplicatedStorage
	end)

	return assetRoot
end

function AssetLibraryService:GetAssetEntries(searchTerm: string?): { TAssetEntry }
	local assetRoot = self:GetAssetRoot()
	if assetRoot == nil then
		return {}
	end

	local assetEntries = {}
	self:_CollectAssetEntries(assetRoot, "", string.lower(searchTerm or ""), assetEntries)

	table.sort(assetEntries, function(leftAsset, rightAsset)
		return leftAsset.Path < rightAsset.Path
	end)

	return assetEntries
end

function AssetLibraryService:SaveSelectionToLibrary(assetNameOverride: string?): TPluginActionResult
	local selectionRoots = self.Selection.GetSelectionRoots()
	if #selectionRoots == 0 then
		return self:_CreateResult(false, 0, 0, "Select at least one instance before saving to the library.")
	end

	local assetRoot = self:EnsureAssetRoot()
	local assetName = self:_ResolveAssetName(selectionRoots, assetNameOverride)
	local assetContainer = self:_BuildAssetContainer(selectionRoots, assetName)

	self.History:Run("Save Asset To Library", function()
		assetContainer.Parent = assetRoot
	end)

	local assetPath = assetRoot.Name .. "/" .. assetContainer.Name
	return self:_CreateResult(true, 1, 0, "Saved asset to " .. assetPath .. ".", assetPath)
end

function AssetLibraryService:InsertAsset(assetPath: string): TPluginActionResult
	local assetEntry = self:_FindAssetByPath(assetPath)
	if assetEntry == nil then
		return self:_CreateResult(false, 0, 0, "Selected asset was not found in the library.")
	end

	local insertedClone = assetEntry.Instance:Clone()

	self.History:Run("Insert Asset", function()
		insertedClone.Parent = Workspace
	end)

	self.Selection.SetSelection({ insertedClone })

	return self:_CreateResult(true, 1, 0, "Inserted asset " .. assetEntry.Path .. ".", assetEntry.Path)
end

function AssetLibraryService:DeleteAsset(assetPath: string): TPluginActionResult
	local assetEntry = self:_FindAssetByPath(assetPath)
	if assetEntry == nil then
		return self:_CreateResult(false, 0, 0, "Selected asset was not found in the library.")
	end

	local assetRoot = self:GetAssetRoot()
	if assetRoot == nil then
		return self:_CreateResult(false, 0, 0, "Asset root is missing. Create it before deleting assets.")
	end

	local deleteFolder = self:_EnsureDeleteFolder(assetRoot)
	local targetName = self:_ResolveUniqueChildName(deleteFolder, assetEntry.Instance.Name)

	self.History:Run("Delete Asset", function()
		assetEntry.Instance.Name = targetName
		assetEntry.Instance.Parent = deleteFolder
	end)

	return self:_CreateResult(true, 1, 0, "Moved asset " .. assetEntry.Path .. " to " .. DELETE_FOLDER_NAME .. ".", assetEntry.Path)
end

function AssetLibraryService:_CollectAssetEntries(rootInstance: Instance, currentPath: string, normalizedSearchTerm: string, assetEntries: { TAssetEntry })
	for _, childInstance in rootInstance:GetChildren() do
		local isDeleteBucket = currentPath == "" and childInstance:IsA("Folder") and childInstance.Name == DELETE_FOLDER_NAME
		if not isDeleteBucket then
			local nextPath = if currentPath == "" then childInstance.Name else currentPath .. "/" .. childInstance.Name

			if childInstance:IsA("Model") then
				if normalizedSearchTerm == "" or string.find(string.lower(nextPath), normalizedSearchTerm, 1, true) then
					table.insert(assetEntries, {
						Name = childInstance.Name,
						Path = nextPath,
						Instance = childInstance,
					})
				end
			elseif childInstance:IsA("Folder") then
				self:_CollectAssetEntries(childInstance, nextPath, normalizedSearchTerm, assetEntries)
			end
		end
	end
end

function AssetLibraryService:_EnsureDeleteFolder(assetRoot: Folder): Folder
	local existingDeleteFolder = assetRoot:FindFirstChild(DELETE_FOLDER_NAME)
	if existingDeleteFolder and existingDeleteFolder:IsA("Folder") then
		return existingDeleteFolder
	end

	local deleteFolder = Instance.new("Folder")
	deleteFolder.Name = DELETE_FOLDER_NAME
	deleteFolder.Parent = assetRoot
	return deleteFolder
end

function AssetLibraryService:_ResolveUniqueChildName(parentInstance: Instance, preferredName: string): string
	if parentInstance:FindFirstChild(preferredName) == nil then
		return preferredName
	end

	local suffix = 2
	local candidateName = preferredName .. "_" .. tostring(suffix)

	while parentInstance:FindFirstChild(candidateName) ~= nil do
		suffix = suffix + 1
		candidateName = preferredName .. "_" .. tostring(suffix)
	end

	return candidateName
end

function AssetLibraryService:_ResolveAssetName(selectionRoots: { Instance }, assetNameOverride: string?): string
	local normalizedName = string.gsub(assetNameOverride or "", "^%s*(.-)%s*$", "%1")
	if normalizedName ~= "" then
		return normalizedName
	end

	if #selectionRoots == 1 then
		return selectionRoots[1].Name
	end

	return "SavedAsset"
end

function AssetLibraryService:_BuildAssetContainer(selectionRoots: { Instance }, assetName: string): Instance
	if #selectionRoots == 1 and selectionRoots[1]:IsA("Model") then
		local modelClone = selectionRoots[1]:Clone()
		modelClone.Name = assetName
		return modelClone
	end

	local assetModel = Instance.new("Model")
	assetModel.Name = assetName

	for _, selectionRoot in selectionRoots do
		local clonedRoot = selectionRoot:Clone()
		clonedRoot.Parent = assetModel
	end

	return assetModel
end

function AssetLibraryService:_FindAssetByPath(assetPath: string): TAssetEntry?
	local normalizedLookupPath = self:_NormalizeAssetPath(assetPath)

	for _, assetEntry in self:GetAssetEntries(nil) do
		if assetEntry.Path == normalizedLookupPath then
			return assetEntry
		end
	end

	return nil
end

function AssetLibraryService:_NormalizeAssetPath(assetPath: string): string
	local rootName = self.Settings:GetAssetRootName()
	local rootPrefix = rootName .. "/"

	if string.sub(assetPath, 1, #rootPrefix) == rootPrefix then
		return string.sub(assetPath, #rootPrefix + 1)
	end

	return assetPath
end

function AssetLibraryService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string, assetPath: string?): TPluginActionResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
		Path = assetPath,
	}
end

return AssetLibraryService
