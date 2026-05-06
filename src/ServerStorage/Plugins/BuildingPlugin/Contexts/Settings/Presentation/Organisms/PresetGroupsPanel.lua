--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TPresetGroupsPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	PresetGroupLabelInput: string,
	PresetGroupFolderNamesInput: string,
	PresetGroupIncludesInput: string,
	GroupLabels: { string },
	SelectedPresetGroupLabel: string?,
	PreviewText: string,
	HelpText: string,
	ExampleText: string,
	StructurePreviewText: string,
	OnPresetGroupLabelInputChanged: (value: string) -> (),
	OnPresetGroupFolderNamesInputChanged: (value: string) -> (),
	OnPresetGroupIncludesInputChanged: (value: string) -> (),
	OnSelectedPresetGroupLabelChanged: (value: string?) -> (),
	OnSavePresetGroup: () -> (),
	OnLoadSelectedPresetGroup: () -> (),
	OnDeleteSelectedPresetGroup: () -> (),
}

local function PresetGroupsPanel(props: TPresetGroupsPanelProps)
	local hasSelectedGroup = props.SelectedPresetGroupLabel ~= nil

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 1,
		Title = "Folder Preset Groups",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, {
		Help = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = props.HelpText,
		}),
		Example = React.createElement(TextBlock, {
			LayoutOrder = 2,
			Text = props.ExampleText,
		}),
		LabelInput = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 3,
			OnChanged = props.OnPresetGroupLabelInputChanged,
			PlaceholderText = "Label (example: Organization)...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.PresetGroupLabelInput,
		}),
		FolderNamesInput = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 4,
			OnChanged = props.OnPresetGroupFolderNamesInputChanged,
			PlaceholderText = "Folder Names (example: Props, Decor, Structure)...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.PresetGroupFolderNamesInput,
		}),
		IncludesInput = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 5,
			OnChanged = props.OnPresetGroupIncludesInputChanged,
			PlaceholderText = "Includes Labels (example: Misc, LightingSet)...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.PresetGroupIncludesInput,
		}),
		Save = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 6,
			OnActivated = props.OnSavePresetGroup,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Save Preset Group",
		}),
		GroupDropdown = React.createElement(StudioComponents.Dropdown, {
			DefaultText = "Select preset group...",
			Items = props.GroupLabels,
			LayoutOrder = 7,
			OnItemSelected = props.OnSelectedPresetGroupLabelChanged,
			SelectedItem = props.SelectedPresetGroupLabel,
			Size = UDim2.new(1, 0, 0, 24),
		}),
		Load = React.createElement(StudioComponents.Button, {
			Interactable = hasSelectedGroup,
			LayoutOrder = 8,
			OnActivated = props.OnLoadSelectedPresetGroup,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Load Selected",
		}),
		Delete = React.createElement(StudioComponents.Button, {
			Interactable = hasSelectedGroup,
			LayoutOrder = 9,
			OnActivated = props.OnDeleteSelectedPresetGroup,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Delete Selected",
		}),
		Preview = React.createElement(TextBlock, {
			LayoutOrder = 10,
			Text = "Current groups: " .. props.PreviewText,
		}),
		StructurePreview = React.createElement(TextBlock, {
			LayoutOrder = 11,
			Text = "Structure Preview:\n" .. props.StructurePreviewText,
		}),
	})
end

return PresetGroupsPanel
