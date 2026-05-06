--!strict

local Constants = require(script.Parent.Parent.Parent.Parent.Parent.Constants)
local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)
local AssetsAtom = require(script.Parent.Parent.Parent.Infrastructure.AssetsAtom)

local function useAssetsActions()
	local services = usePluginServices()

	local function syncSelectedLibraryAssetPath(assetEntries)
		local currentSelection = AssetsAtom.GetState().SelectedLibraryAssetPath
		if currentSelection == nil then
			return
		end

		for _, assetEntry in assetEntries do
			if assetEntry.Path == currentSelection then
				return
			end
		end

		AssetsAtom.SetSelectedLibraryAssetPath(nil)
	end

	local function refreshAssets()
		local state = AssetsAtom.GetState()
		AssetsAtom.SetAssetRootExists(services.Assets:GetAssetRoot() ~= nil)
		local recentAssetEntries = services.Assets:GetAssetEntries(nil)
		local recentAssetPaths = {}
		for _, assetEntry in recentAssetEntries do
			table.insert(recentAssetPaths, assetEntry.Path)
		end

		AssetsAtom.SetRecentAssets(recentAssetPaths)
		local assetEntries = services.Assets:GetAssetEntries(state.SearchText)
		AssetsAtom.SetAssetEntries(assetEntries)
		syncSelectedLibraryAssetPath(assetEntries)
	end

	local function applyResult(result)
		AppAtom.SetStatus(result.Message, if result.Success then "Success" else "Error")

		refreshAssets()
	end

	return {
		RefreshAssets = refreshAssets,
		SetSearchText = function(searchText: string)
			AssetsAtom.SetSearchText(searchText)
			local assetEntries = services.Assets:GetAssetEntries(searchText)
			AssetsAtom.SetAssetEntries(assetEntries)
			syncSelectedLibraryAssetPath(assetEntries)
		end,
		SetAssetName = function(assetName: string)
			AssetsAtom.SetAssetName(assetName)
		end,
		SetSelectedLibraryAssetPath = function(assetPath: string?)
			AssetsAtom.SetSelectedLibraryAssetPath(assetPath)
		end,
		EnsureAssetRoot = function()
			services.Assets:EnsureAssetRoot()
			AppAtom.SetStatus("Ensured ReplicatedStorage." .. Constants.AssetRootName .. ".", "Success")
			refreshAssets()
		end,
		SaveSelection = function()
			applyResult(services.Assets:SaveSelectionToLibrary(AssetsAtom.GetState().AssetName))
		end,
		InsertAsset = function(assetPath: string)
			applyResult(services.Assets:InsertAsset(assetPath))
		end,
		InsertSelectedLibraryAsset = function()
			local selectedPath = AssetsAtom.GetState().SelectedLibraryAssetPath
			if selectedPath == nil then
				AppAtom.SetStatus("Select a library asset before inserting.", "Error")
				return
			end

			applyResult(services.Assets:InsertAsset(selectedPath))
		end,
		DeleteSelectedLibraryAsset = function()
			local selectedPath = AssetsAtom.GetState().SelectedLibraryAssetPath
			if selectedPath == nil then
				AppAtom.SetStatus("Select a library asset before deleting.", "Error")
				return
			end

			local result = services.Assets:DeleteAsset(selectedPath)
			applyResult(result)
		end,
	}
end

return useAssetsActions
