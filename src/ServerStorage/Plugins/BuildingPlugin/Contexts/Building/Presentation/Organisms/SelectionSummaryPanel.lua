--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TSelectionSummaryPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	SelectionText: string,
}

local function SelectionSummaryPanel(props: TSelectionSummaryPanelProps)
	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 1,
		Title = "Selection",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, {
		Summary = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = props.SelectionText,
		}),
	})
end

return SelectionSummaryPanel
