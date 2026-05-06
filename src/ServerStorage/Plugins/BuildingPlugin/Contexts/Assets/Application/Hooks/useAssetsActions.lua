--!strict

local Constants = require(script.Parent.Parent.Parent.Parent.Parent.Constants)
local AppAtom = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.AppAtom)
local usePluginServices = require(script.Parent.Parent.Parent.Parent.App.Infrastructure.usePluginServices)
local AssetsAtom = require(script.Parent.Parent.Parent.Infrastructure.AssetsAtom)

local function useAssetsActions()
	local services = usePluginServices()

	local function refreshAssets()
		local state = AssetsAtom.GetState()
		AssetsAtom.SetAssetRootExists(services.Assets:GetAssetRoot() ~= nil)
		AssetsAtom.SetRecentAssets(services.Settings:GetRecentAssets())
		AssetsAtom.SetAssetEntries(services.Assets:GetAssetEntries(state.SearchText))
	end

	local function applyResult(result)
		AppAtom.SetStatus(result.Message, if result.Success then "Success" else "Error")

		if result.Success and result.Path ~= nil then
			services.Settings:PushRecentAsset(result.Path)
		end

		refreshAssets()
	end

	return {
		RefreshAssets = refreshAssets,
		SetSearchText = function(searchText: string)
			AssetsAtom.SetSearchText(searchText)
			AssetsAtom.SetAssetEntries(services.Assets:GetAssetEntries(searchText))
		end,
		SetAssetName = function(assetName: string)
			AssetsAtom.SetAssetName(assetName)
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
	}
end

return useAssetsActions
