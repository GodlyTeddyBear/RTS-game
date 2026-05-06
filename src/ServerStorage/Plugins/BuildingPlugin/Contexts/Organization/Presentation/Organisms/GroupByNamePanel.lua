--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TGroupByNamePanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	MatchObjectName: string,
	DestinationFolderName: string,
	SelectedChildName: string?,
	AvailableChildNames: { string },
	InstructionText: string,
	NameSelectorHelpText: string,
	MatchNameHelpText: string,
	DestinationNameHelpText: string,
	OnMatchObjectNameChanged: (matchObjectName: string) -> (),
	OnDestinationFolderNameChanged: (folderName: string) -> (),
	OnSelectedChildNameChanged: (childName: string?) -> (),
	OnGroupByName: () -> (),
}

local function GroupByNamePanel(props: TGroupByNamePanelProps)
	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 1,
		Title = "Group By Name",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, {
		Help = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = props.InstructionText,
		}),
		NameDropdown = React.createElement(StudioComponents.Dropdown, {
			DefaultText = "Select object name from selected parent...",
			Items = props.AvailableChildNames,
			LayoutOrder = 2,
			OnItemSelected = props.OnSelectedChildNameChanged,
			SelectedItem = props.SelectedChildName,
			Size = UDim2.new(1, 0, 0, 24),
		}),
		NameHelp = React.createElement(TextBlock, {
			LayoutOrder = 3,
			Text = props.NameSelectorHelpText,
		}),
		MatchNameHelp = React.createElement(TextBlock, {
			LayoutOrder = 4,
			Text = props.MatchNameHelpText,
		}),
		MatchNameInput = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 5,
			OnChanged = props.OnMatchObjectNameChanged,
			PlaceholderText = "Object Name To Find (example: Wall)...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.MatchObjectName,
		}),
		DestinationHelp = React.createElement(TextBlock, {
			LayoutOrder = 6,
			Text = props.DestinationNameHelpText,
		}),
		DestinationInput = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 7,
			OnChanged = props.OnDestinationFolderNameChanged,
			PlaceholderText = "Folder Name To Create/Use (example: Walls)...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.DestinationFolderName,
		}),
		Action = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 8,
			OnActivated = props.OnGroupByName,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Group Objects Into Folder",
		}),
	})
end

return GroupByNamePanel
