--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TPresetFoldersPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	PresetLabels: { string },
	SelectedPresetLabel: string?,
	OnSelectedPresetLabelChanged: (label: string?) -> (),
	OnCreatePresetFolders: () -> (),
}

local function PresetFoldersPanel(props: TPresetFoldersPanelProps)
	local hasPresetLabels = #props.PresetLabels > 0
	local hasSelectedPreset = props.SelectedPresetLabel ~= nil

	local children: { [string]: React.ReactNode } = {
		Help = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = "Choose a preset group, then create its folder structure under the selected parent instance.",
		}),
		Dropdown = React.createElement(StudioComponents.Dropdown, {
			DefaultText = "Select preset group...",
			Items = props.PresetLabels,
			LayoutOrder = 2,
			OnItemSelected = props.OnSelectedPresetLabelChanged,
			SelectedItem = props.SelectedPresetLabel,
			Size = UDim2.new(1, 0, 0, 24),
		}),
		Apply = React.createElement(StudioComponents.MainButton, {
			Interactable = hasSelectedPreset,
			LayoutOrder = 3,
			OnActivated = props.OnCreatePresetFolders,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Create Preset Folders",
		}),
	}

	if not hasPresetLabels then
		children.Empty = React.createElement(TextBlock, {
			LayoutOrder = 4,
			Text = "No preset groups configured. Use the Settings tab to add one.",
		})
	end

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 2,
		Title = "Create Folder Presets",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, children)
end

return PresetFoldersPanel
