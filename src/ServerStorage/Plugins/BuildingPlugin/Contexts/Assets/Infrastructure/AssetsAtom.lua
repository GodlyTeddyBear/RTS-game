--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local PluginTypes = require(script.Parent.Parent.Parent.Parent.Types.PluginTypes)

type TAssetEntry = PluginTypes.TAssetEntry

export type TAssetsState = {
	AssetRootExists: boolean,
	SearchText: string,
	AssetName: string,
	SelectedLibraryAssetPath: string?,
	RecentAssets: { string },
	AssetEntries: { TAssetEntry },
}

local assetsAtom = Charm.atom({
	AssetRootExists = false,
	SearchText = "",
	AssetName = "",
	SelectedLibraryAssetPath = nil,
	RecentAssets = {},
	AssetEntries = {},
} :: TAssetsState)

local AssetsAtom = {}

function AssetsAtom.GetAtom()
	return assetsAtom
end

function AssetsAtom.GetState(): TAssetsState
	return assetsAtom()
end

function AssetsAtom.SetAssetRootExists(assetRootExists: boolean)
	local state = assetsAtom()
	assetsAtom({
		AssetRootExists = assetRootExists,
		SearchText = state.SearchText,
		AssetName = state.AssetName,
		SelectedLibraryAssetPath = state.SelectedLibraryAssetPath,
		RecentAssets = state.RecentAssets,
		AssetEntries = state.AssetEntries,
	})
end

function AssetsAtom.SetSearchText(searchText: string)
	local state = assetsAtom()
	assetsAtom({
		AssetRootExists = state.AssetRootExists,
		SearchText = searchText,
		AssetName = state.AssetName,
		SelectedLibraryAssetPath = state.SelectedLibraryAssetPath,
		RecentAssets = state.RecentAssets,
		AssetEntries = state.AssetEntries,
	})
end

function AssetsAtom.SetAssetName(assetName: string)
	local state = assetsAtom()
	assetsAtom({
		AssetRootExists = state.AssetRootExists,
		SearchText = state.SearchText,
		AssetName = assetName,
		SelectedLibraryAssetPath = state.SelectedLibraryAssetPath,
		RecentAssets = state.RecentAssets,
		AssetEntries = state.AssetEntries,
	})
end

function AssetsAtom.SetSelectedLibraryAssetPath(selectedLibraryAssetPath: string?)
	local state = assetsAtom()
	assetsAtom({
		AssetRootExists = state.AssetRootExists,
		SearchText = state.SearchText,
		AssetName = state.AssetName,
		SelectedLibraryAssetPath = selectedLibraryAssetPath,
		RecentAssets = state.RecentAssets,
		AssetEntries = state.AssetEntries,
	})
end

function AssetsAtom.SetRecentAssets(recentAssets: { string })
	local state = assetsAtom()
	assetsAtom({
		AssetRootExists = state.AssetRootExists,
		SearchText = state.SearchText,
		AssetName = state.AssetName,
		SelectedLibraryAssetPath = state.SelectedLibraryAssetPath,
		RecentAssets = recentAssets,
		AssetEntries = state.AssetEntries,
	})
end

function AssetsAtom.SetAssetEntries(assetEntries: { TAssetEntry })
	local state = assetsAtom()
	assetsAtom({
		AssetRootExists = state.AssetRootExists,
		SearchText = state.SearchText,
		AssetName = state.AssetName,
		SelectedLibraryAssetPath = state.SelectedLibraryAssetPath,
		RecentAssets = state.RecentAssets,
		AssetEntries = assetEntries,
	})
end

return AssetsAtom
