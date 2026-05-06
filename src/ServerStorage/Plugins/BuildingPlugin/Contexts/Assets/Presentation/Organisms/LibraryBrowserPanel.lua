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
	SearchText: string,
	AssetEntries: { TAssetEntry },
	OnSearchChanged: (searchText: string) -> (),
	OnInsertAsset: (assetPath: string) -> (),
}

local function LibraryBrowserPanel(props: TLibraryBrowserPanelProps)
	local children: { [string]: React.ReactNode } = {
		Search = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 1,
			OnChanged = props.OnSearchChanged,
			PlaceholderText = "Search saved assets...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.SearchText,
		}),
	}

	if #props.AssetEntries == 0 then
		children.Empty = React.createElement(TextBlock, {
			LayoutOrder = 2,
			Text = "No saved models matched the current search.",
		})
	else
		for index, assetEntry in ipairs(props.AssetEntries) do
			children["Asset" .. tostring(index)] = React.createElement(StudioComponents.Button, {
				LayoutOrder = 1 + index,
				OnActivated = function()
					props.OnInsertAsset(assetEntry.Path)
				end,
				Size = UDim2.new(1, 0, 0, 24),
				Text = assetEntry.Path,
			})
		end
	end

	return React.createElement(SectionPanel, {
		LayoutOrder = 4,
		Title = "Library Browser",
	}, children)
end

return LibraryBrowserPanel
