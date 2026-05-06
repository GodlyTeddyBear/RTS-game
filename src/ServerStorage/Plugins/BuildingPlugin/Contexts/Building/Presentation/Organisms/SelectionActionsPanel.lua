--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)

type TSelectionActionsPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	OnDuplicateSelection: () -> (),
}

local function SelectionActionsPanel(props: TSelectionActionsPanelProps)
	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 3,
		Title = "Selection Actions",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, {
		Duplicate = React.createElement(StudioComponents.Button, {
			LayoutOrder = 1,
			OnActivated = props.OnDuplicateSelection,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Duplicate Selection",
		}),
	})
end

return SelectionActionsPanel
