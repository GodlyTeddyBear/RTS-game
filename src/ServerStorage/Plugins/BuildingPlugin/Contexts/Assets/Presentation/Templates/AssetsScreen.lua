--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useAssetsState = require(script.Parent.Parent.Parent.Application.Hooks.useAssetsState)
local useAssetsActions = require(script.Parent.Parent.Parent.Application.Hooks.useAssetsActions)
local AssetsViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.AssetsViewModel)
local AssetRootPanel = require(script.Parent.Parent.Organisms.AssetRootPanel)
local AssetSavePanel = require(script.Parent.Parent.Organisms.AssetSavePanel)
local RecentAssetsPanel = require(script.Parent.Parent.Organisms.RecentAssetsPanel)
local LibraryBrowserPanel = require(script.Parent.Parent.Organisms.LibraryBrowserPanel)

local function AssetsScreen()
	local assetsState = useAssetsState()
	local assetsActions = useAssetsActions()

	React.useEffect(function()
		assetsActions.RefreshAssets()
	end, {})

	local viewModel = React.useMemo(function()
		return AssetsViewModel.FromState(assetsState)
	end, { assetsState })

	return React.createElement(StudioComponents.ScrollFrame, {
		Layout = {
			ClassName = "UIListLayout",
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		},
		PaddingBottom = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 10),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}, {
		AssetRoot = React.createElement(AssetRootPanel, {
			AssetRootExists = viewModel.AssetRootExists,
			AssetRootStatusText = viewModel.AssetRootStatusText,
			OnCreateAssetRoot = assetsActions.EnsureAssetRoot,
		}),
		SaveSelection = React.createElement(AssetSavePanel, {
			AssetName = viewModel.AssetName,
			OnAssetNameChanged = assetsActions.SetAssetName,
			OnSaveSelection = assetsActions.SaveSelection,
		}),
		RecentAssets = React.createElement(RecentAssetsPanel, {
			RecentAssets = viewModel.RecentAssets,
			OnInsertAsset = assetsActions.InsertAsset,
		}),
		LibraryBrowser = React.createElement(LibraryBrowserPanel, {
			AssetEntries = viewModel.AssetEntries,
			OnInsertAsset = assetsActions.InsertAsset,
			OnSearchChanged = assetsActions.SetSearchText,
			SearchText = viewModel.SearchText,
		}),
	})
end

return AssetsScreen
