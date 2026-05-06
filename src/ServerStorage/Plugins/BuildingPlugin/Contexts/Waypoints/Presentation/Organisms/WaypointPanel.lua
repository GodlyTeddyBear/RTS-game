--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TWaypointPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	WaypointNameInput: string,
	WaypointNames: { string },
	SelectedWaypointName: string?,
	OnWaypointNameInputChanged: (name: string) -> (),
	OnSelectedWaypointNameChanged: (name: string?) -> (),
	OnSaveWaypoint: () -> (),
	OnGoToWaypoint: () -> (),
}

local function WaypointPanel(props: TWaypointPanelProps)
	local hasWaypoints = #props.WaypointNames > 0
	local hasSelectedWaypoint = props.SelectedWaypointName ~= nil

	local children: { [string]: React.ReactNode } = {
		NameInput = React.createElement(StudioComponents.TextInput, {
			ClearTextOnFocus = false,
			LayoutOrder = 1,
			OnChanged = props.OnWaypointNameInputChanged,
			PlaceholderText = "Waypoint name...",
			Size = UDim2.new(1, 0, 0, 24),
			Text = props.WaypointNameInput,
		}),
		SaveButton = React.createElement(StudioComponents.MainButton, {
			LayoutOrder = 2,
			OnActivated = props.OnSaveWaypoint,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Save Current Camera",
		}),
		WaypointDropdown = React.createElement(StudioComponents.Dropdown, {
			DefaultText = "Select waypoint...",
			Items = props.WaypointNames,
			LayoutOrder = 3,
			OnItemSelected = props.OnSelectedWaypointNameChanged,
			SelectedItem = props.SelectedWaypointName,
			Size = UDim2.new(1, 0, 0, 24),
		}),
		GoButton = React.createElement(StudioComponents.Button, {
			Interactable = hasSelectedWaypoint,
			LayoutOrder = 4,
			OnActivated = props.OnGoToWaypoint,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Go To Waypoint",
		}),
	}

	if not hasWaypoints then
		children.Empty = React.createElement(TextBlock, {
			LayoutOrder = 5,
			Text = "No waypoints saved yet.",
		})
	end

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 1,
		Title = "Waypoint Manager",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, children)
end

return WaypointPanel
