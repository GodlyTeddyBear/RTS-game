--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TAssetEntry = {
	Name: string,
	Path: string,
	Instance: Instance,
}

type TLibraryBrowserPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	SearchText: string,
	SelectedAssetPath: string?,
	AssetEntries: { TAssetEntry },
	OnSearchChanged: (searchText: string) -> (),
	OnSelectedAssetPathChanged: (assetPath: string?) -> (),
	OnInsertSelectedAsset: () -> (),
	OnDeleteSelectedAsset: () -> (),
}

local function LibraryBrowserPanel(props: TLibraryBrowserPanelProps)
	local hasEntries = #props.AssetEntries > 0
	local hasSelection = props.SelectedAssetPath ~= nil
	local dropdownItems = {}

	for _, assetEntry in props.AssetEntries do
		table.insert(dropdownItems, assetEntry.Path)
	end

	local children: { [string]: React.ReactNode } = {
		Search = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 1,
			OnChanged = props.OnSearchChanged,
			PlaceholderText = "Search saved assets...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.SearchText,
		}),
		AssetDropdown = React.createElement(StudioComponents.Dropdown, {
			DefaultText = "Select saved asset...",
			Items = dropdownItems,
			LayoutOrder = 2,
			OnItemSelected = props.OnSelectedAssetPathChanged,
			SelectedItem = props.SelectedAssetPath,
			Size = UDim2.new(1, 0, 0, 24),
		}),
		InsertButton = React.createElement(StudioComponents.MainButton, {
			Interactable = hasSelection,
			LayoutOrder = 3,
			OnActivated = props.OnInsertSelectedAsset,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Insert Selected",
		}),
		DeleteButton = React.createElement(StudioComponents.Button, {
			Interactable = hasSelection,
			LayoutOrder = 4,
			OnActivated = props.OnDeleteSelectedAsset,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Delete Selected",
		}),
	}

	if not hasEntries then
		children.Empty = React.createElement(TextBlock, {
			LayoutOrder = 5,
			Text = "No saved models matched the current search.",
		})
	end

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 4,
		Title = "Library Browser",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, children)
end

return LibraryBrowserPanel
