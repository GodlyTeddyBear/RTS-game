--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TFolderPresetsPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	PresetText: string,
	PreviewText: string,
	OnPresetTextChanged: (presetText: string) -> (),
	OnSavePresets: () -> (),
}

local function FolderPresetsPanel(props: TFolderPresetsPanelProps)
	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 1,
		Title = "Folder Presets",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, {
		Help = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = "Comma-separated preset names. These are used by the Building tab folder shortcuts.",
		}),
		Input = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 2,
			OnChanged = props.OnPresetTextChanged,
			PlaceholderText = "Comma-separated preset names...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.PresetText,
		}),
		Preview = React.createElement(TextBlock, {
			LayoutOrder = 3,
			Text = "Current presets: " .. props.PreviewText,
		}),
		Save = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 4,
			OnActivated = props.OnSavePresets,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Save Presets",
		}),
	})
end

return FolderPresetsPanel
