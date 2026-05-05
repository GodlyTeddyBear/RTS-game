--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SelectionHelper = require(script.Parent.SelectionHelper)

export type TAssetEntry = {
	Name: string,
	Path: string,
	Instance: Instance,
}

export type TResult = {
	Success: boolean,
	ChangedCount: number,
	SkippedCount: number,
	Message: string,
	Path: string?,
}

local AssetLibraryService = {}
AssetLibraryService.__index = AssetLibraryService

function AssetLibraryService.new(settingsStore, historyAdapter)
	local self = setmetatable({}, AssetLibraryService)
	self.SettingsStore = settingsStore
	self.HistoryAdapter = historyAdapter
	return self
end

function AssetLibraryService:GetAssetRoot(): Folder?
	local assetRootName = self.SettingsStore:GetAssetRootName()
	local assetRoot = ReplicatedStorage:FindFirstChild(assetRootName)

	if assetRoot and assetRoot:IsA("Folder") then
		return assetRoot
	end

	return nil
end

function AssetLibraryService:EnsureAssetRoot(): Folder
	local existingRoot = self:GetAssetRoot()
	if existingRoot then
		return existingRoot
	end

	local assetRoot = Instance.new("Folder")
	assetRoot.Name = self.SettingsStore:GetAssetRootName()

	self.HistoryAdapter:Run("Create Asset Root", function()
		assetRoot.Parent = ReplicatedStorage
	end)

	return assetRoot
end

function AssetLibraryService:GetAssetEntries(searchTerm: string?): { TAssetEntry }
	local assetRoot = self:GetAssetRoot()
	if assetRoot == nil then
		return {}
	end

	local normalizedSearchTerm = string.lower(searchTerm or "")
	local assetEntries = {}

	self:_CollectAssetEntries(assetRoot, "", normalizedSearchTerm, assetEntries)
	table.sort(assetEntries, function(leftAsset, rightAsset)
		return leftAsset.Path < rightAsset.Path
	end)

	return assetEntries
end

function AssetLibraryService:SaveSelectionToLibrary(assetNameOverride: string?): TResult
	local selectionRoots = SelectionHelper.GetSelectionRoots()
	if #selectionRoots == 0 then
		return self:_CreateResult(false, 0, 0, "Select at least one instance before saving to the library.")
	end

	local assetRoot = self:EnsureAssetRoot()
	local assetName = self:_ResolveAssetName(selectionRoots, assetNameOverride)
	local assetContainer = self:_BuildAssetContainer(selectionRoots, assetName)

	self.HistoryAdapter:Run("Save Asset To Library", function()
		assetContainer.Parent = assetRoot
	end)

	local assetPath = assetRoot.Name .. "/" .. assetContainer.Name

	return self:_CreateResult(true, 1, 0, "Saved asset to " .. assetPath .. ".", assetPath)
end

function AssetLibraryService:InsertAsset(assetPath: string): TResult
	local assetEntry = self:_FindAssetByPath(assetPath)
	if assetEntry == nil then
		return self:_CreateResult(false, 0, 0, "Selected asset was not found in the library.")
	end

	local insertedClone = assetEntry.Instance:Clone()

	self.HistoryAdapter:Run("Insert Asset", function()
		insertedClone.Parent = Workspace
	end)

	SelectionHelper.SetSelection({ insertedClone })

	return self:_CreateResult(true, 1, 0, "Inserted asset " .. assetEntry.Path .. ".", assetEntry.Path)
end

function AssetLibraryService:_CollectAssetEntries(rootInstance: Instance, currentPath: string, normalizedSearchTerm: string, assetEntries: { TAssetEntry })
	for _, childInstance in rootInstance:GetChildren() do
		local nextPath = if currentPath == "" then childInstance.Name else currentPath .. "/" .. childInstance.Name

		if childInstance:IsA("Model") then
			if (normalizedSearchTerm == "") or string.find(string.lower(nextPath), normalizedSearchTerm, 1, true) then
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
	if (#selectionRoots == 1) and selectionRoots[1]:IsA("Model") then
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
	for _, assetEntry in self:GetAssetEntries(nil) do
		if assetEntry.Path == assetPath then
			return assetEntry
		end
	end

	return nil
end

function AssetLibraryService:_CreateResult(success: boolean, changedCount: number, skippedCount: number, message: string, assetPath: string?): TResult
	return {
		Success = success,
		ChangedCount = changedCount,
		SkippedCount = skippedCount,
		Message = message,
		Path = assetPath,
	}
end

return AssetLibraryService
