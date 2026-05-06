--!strict

local Constants = require(script.Parent.Parent.Parent.Parent.Parent.Constants)

local AssetsViewModel = {}

function AssetsViewModel.FromState(state)
	local assetRootStatusText = if state.AssetRootExists
		then "Asset root is available at ReplicatedStorage." .. Constants.AssetRootName .. "."
		else "Asset root is missing. Create it before saving or browsing plugin assets."

	return table.freeze({
		AssetRootExists = state.AssetRootExists,
		AssetRootStatusText = assetRootStatusText,
		SearchText = state.SearchText,
		AssetName = state.AssetName,
		RecentAssets = state.RecentAssets,
		AssetEntries = state.AssetEntries,
	})
end

return AssetsViewModel
