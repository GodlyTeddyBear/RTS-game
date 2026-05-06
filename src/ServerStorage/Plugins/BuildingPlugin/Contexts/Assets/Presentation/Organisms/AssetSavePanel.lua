--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)

type TAssetSavePanelProps = {
	AssetName: string,
	OnAssetNameChanged: (assetName: string) -> (),
	OnSaveSelection: () -> (),
}

local function AssetSavePanel(props: TAssetSavePanelProps)
	return React.createElement(SectionPanel, {
		LayoutOrder = 2,
		Title = "Save Selection",
	}, {
		NameInput = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 1,
			OnChanged = props.OnAssetNameChanged,
			PlaceholderText = "Optional asset name for save...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.AssetName,
		}),
		SaveButton = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 2,
			OnActivated = props.OnSaveSelection,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Save Selection",
		}),
	})
end

return AssetSavePanel
