--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)

type TWeldingActionsPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	OnCreateSingleWeld: () -> (),
	OnCreateMassWeld: () -> (),
}

local function WeldingActionsPanel(props: TWeldingActionsPanelProps)
	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 1,
		Title = "Welding Actions",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, {
		SingleWeld = React.createElement(StudioComponents.Button, {
			LayoutOrder = 1,
			OnActivated = props.OnCreateSingleWeld,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Single Weld",
		}),
		MassWeld = React.createElement(StudioComponents.Button, {
			LayoutOrder = 2,
			OnActivated = props.OnCreateMassWeld,
			Size = UDim2.new(1, 0, 0, 24),
			Text = "Mass Weld",
		}),
	})
end

return WeldingActionsPanel
