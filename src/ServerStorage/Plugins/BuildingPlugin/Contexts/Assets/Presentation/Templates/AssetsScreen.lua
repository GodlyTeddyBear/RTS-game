--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

local useAssetsState = require(script.Parent.Parent.Parent.Application.Hooks.useAssetsState)
local useAssetsActions = require(script.Parent.Parent.Parent.Application.Hooks.useAssetsActions)
local AssetsViewModel = require(script.Parent.Parent.Parent.Application.ViewModels.AssetsViewModel)
local useSettingsState = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsState)
local useSettingsActions = require(script.Parent.Parent.Parent.Parent.Settings.Application.Hooks.useSettingsActions)
local AssetRootPanel = require(script.Parent.Parent.Organisms.AssetRootPanel)
local AssetSavePanel = require(script.Parent.Parent.Organisms.AssetSavePanel)
local RecentAssetsPanel = require(script.Parent.Parent.Organisms.RecentAssetsPanel)
local LibraryBrowserPanel = require(script.Parent.Parent.Organisms.LibraryBrowserPanel)

local SECTION_IDS = {
	AssetRoot = "asset_root",
	SaveSelection = "save_selection",
	RecentAssets = "recent_assets",
	LibraryBrowser = "library_browser",
}

local ASSET_SECTION_IDS = {
	SECTION_IDS.AssetRoot,
	SECTION_IDS.SaveSelection,
	SECTION_IDS.RecentAssets,
	SECTION_IDS.LibraryBrowser,
}

local function isSectionExpanded(sectionExpansionById: { [string]: boolean }, sectionId: string): boolean
	local value = sectionExpansionById[sectionId]
	if value == nil then
		return true
	end

	return value
end

local function AssetsScreen()
	local assetsState = useAssetsState()
	local assetsActions = useAssetsActions()
	local settingsState = useSettingsState()
	local settingsActions = useSettingsActions()

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
		SectionControls = React.createElement("Frame", {
			BackgroundTransparency = 1,
			LayoutOrder = 0,
			Size = UDim2.new(1, 0, 0, 24),
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			ExpandAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 1,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(ASSET_SECTION_IDS, true)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Expand All",
			}),
			CollapseAll = React.createElement(StudioComponents.Button, {
				LayoutOrder = 2,
				OnActivated = function()
					settingsActions.SetSectionsExpanded(ASSET_SECTION_IDS, false)
				end,
				Size = UDim2.new(0.5, -4, 0, 24),
				Text = "Collapse All",
			}),
		}),
		AssetRoot = React.createElement(AssetRootPanel, {
			SectionId = SECTION_IDS.AssetRoot,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.AssetRoot),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			AssetRootExists = viewModel.AssetRootExists,
			AssetRootStatusText = viewModel.AssetRootStatusText,
			OnCreateAssetRoot = assetsActions.EnsureAssetRoot,
		}),
		SaveSelection = React.createElement(AssetSavePanel, {
			SectionId = SECTION_IDS.SaveSelection,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.SaveSelection),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			AssetName = viewModel.AssetName,
			OnAssetNameChanged = assetsActions.SetAssetName,
			OnSaveSelection = assetsActions.SaveSelection,
		}),
		RecentAssets = React.createElement(RecentAssetsPanel, {
			SectionId = SECTION_IDS.RecentAssets,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.RecentAssets),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			RecentAssets = viewModel.RecentAssets,
			OnInsertAsset = assetsActions.InsertAsset,
		}),
		LibraryBrowser = React.createElement(LibraryBrowserPanel, {
			SectionId = SECTION_IDS.LibraryBrowser,
			IsExpanded = isSectionExpanded(settingsState.SectionExpansionById, SECTION_IDS.LibraryBrowser),
			OnExpandedChanged = settingsActions.SetSectionExpanded,
			AssetEntries = viewModel.AssetEntries,
			OnInsertAsset = assetsActions.InsertAsset,
			OnSearchChanged = assetsActions.SetSearchText,
			SearchText = viewModel.SearchText,
		}),
	})
end

return AssetsScreen
