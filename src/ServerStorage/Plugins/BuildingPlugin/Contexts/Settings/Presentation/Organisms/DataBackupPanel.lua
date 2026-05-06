--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TDataBackupPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	SnapshotNames: { string },
	SelectedSnapshotName: string?,
	HelpText: string,
	OnSelectedSnapshotNameChanged: (value: string?) -> (),
	OnExportCurrentData: () -> (),
	OnImportSelectedData: () -> (),
}

local function DataBackupPanel(props: TDataBackupPanelProps)
	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 2,
		Title = "Data Backup",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, {
		Help = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = props.HelpText,
		}),
		Export = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 2,
			OnActivated = props.OnExportCurrentData,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Export Current Data",
		}),
		SnapshotDropdown = React.createElement(StudioComponents.Dropdown, {
			DefaultText = "Select backup snapshot...",
			Items = props.SnapshotNames,
			LayoutOrder = 3,
			OnItemSelected = props.OnSelectedSnapshotNameChanged,
			SelectedItem = props.SelectedSnapshotName,
			Size = UDim2.new(1, 0, 0, 24),
		}),
		Import = React.createElement(StudioComponents.Button, {
			Interactable = props.SelectedSnapshotName ~= nil,
			LayoutOrder = 4,
			OnActivated = props.OnImportSelectedData,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Import Selected Data",
		}),
	})
end

return DataBackupPanel
