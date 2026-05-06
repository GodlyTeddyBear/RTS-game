--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)
local TextBlock = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.TextBlock)

type TSelectionSummaryPanelProps = {
	SelectionText: string,
}

local function SelectionSummaryPanel(props: TSelectionSummaryPanelProps)
	return React.createElement(SectionPanel, {
		LayoutOrder = 1,
		Title = "Selection",
	}, {
		Summary = React.createElement(TextBlock, {
			LayoutOrder = 1,
			Text = props.SelectionText,
		}),
	})
end

return SelectionSummaryPanel
