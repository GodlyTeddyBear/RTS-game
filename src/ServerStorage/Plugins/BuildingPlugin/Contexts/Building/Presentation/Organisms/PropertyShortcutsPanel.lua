--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)
local SectionPanel = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.SectionPanel)

local PROPERTY_ROWS = {
	{
		{ Action = "AnchoredOn", Text = "Anchored On" },
		{ Action = "AnchoredOff", Text = "Anchored Off" },
	},
	{
		{ Action = "CollideOn", Text = "CanCollide On" },
		{ Action = "CollideOff", Text = "CanCollide Off" },
	},
	{
		{ Action = "QueryOn", Text = "CanQuery On" },
		{ Action = "QueryOff", Text = "CanQuery Off" },
	},
	{
		{ Action = "TouchOn", Text = "CanTouch On" },
		{ Action = "TouchOff", Text = "CanTouch Off" },
	},
	{
		{ Action = "Transparency0", Text = "Transparency 0" },
		{ Action = "Transparency25", Text = "Transparency .25" },
	},
	{
		{ Action = "Transparency50", Text = "Transparency .50" },
		{ Action = "Transparency100", Text = "Transparency 1" },
	},
	{
		{ Action = "MaterialPlastic", Text = "SmoothPlastic" },
		{ Action = "MaterialConcrete", Text = "Concrete" },
	},
	{
		{ Action = "MaterialMetal", Text = "Metal" },
		{ Action = "ColorStone", Text = "Stone Grey" },
	},
	{
		{ Action = "ColorWhite", Text = "White" },
		{ Action = "ColorBlack", Text = "Black" },
	},
}

type TPropertyButtonSpec = {
	Action: string,
	Text: string,
}

type TPropertyShortcutsPanelProps = {
	SectionId: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	OnPropertyAction: (actionName: string) -> (),
}

local function createButtonRow(
	layoutOrder: number,
	onPropertyAction: (actionName: string) -> (),
	buttonSpecs: { TPropertyButtonSpec }
)
	local children: { [string]: React.ReactNode } = {
		Layout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for index, buttonSpec in ipairs(buttonSpecs) do
		children["Button" .. tostring(index)] = React.createElement(StudioComponents.Button, {
			LayoutOrder = index,
			OnActivated = function()
				onPropertyAction(buttonSpec.Action)
			end,
			Size = UDim2.new(0.5, -4, 0, 24),
			Text = buttonSpec.Text,
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = layoutOrder,
		Size = UDim2.new(1, 0, 0, 24),
	}, children)
end

local function PropertyShortcutsPanel(props: TPropertyShortcutsPanelProps)
	local children: { [string]: React.ReactNode } = {}

	for index, buttonRow in ipairs(PROPERTY_ROWS) do
		children["Row" .. tostring(index)] = createButtonRow(index, props.OnPropertyAction, buttonRow)
	end

	return React.createElement(SectionPanel, {
		SectionId = props.SectionId,
		LayoutOrder = 4,
		Title = "Property Shortcuts",
		IsExpanded = props.IsExpanded,
		OnExpandedChanged = props.OnExpandedChanged,
	}, children)
end

return PropertyShortcutsPanel
