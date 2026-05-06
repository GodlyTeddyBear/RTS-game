--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

type TSectionPanelProps = {
	SectionId: string,
	Title: string,
	IsExpanded: boolean,
	OnExpandedChanged: (sectionId: string, isExpanded: boolean) -> (),
	LayoutOrder: number?,
	children: React.React_Node,
}

local function SectionPanel(props: TSectionPanelProps)
	local theme = StudioComponents.useTheme()

	return React.createElement("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 0),
	}, {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Header = React.createElement("Frame", {
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 26),
		}, {
			ToggleButton = React.createElement("TextButton", {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Font = Enum.Font.SourceSans,
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
				Text = string.format("%s %s", if props.IsExpanded then "▼" else "▶", props.Title),
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.BrightText),
				TextSize = 16,
				TextXAlignment = Enum.TextXAlignment.Left,
				[React.Event.Activated] = function()
					props.OnExpandedChanged(props.SectionId, not props.IsExpanded)
				end,
			}),
		}),
		Body = if props.IsExpanded
			then React.createElement("Frame", {
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 0),
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingBottom = UDim.new(0, 10),
					PaddingLeft = UDim.new(0, 10),
					PaddingRight = UDim.new(0, 10),
				}),
				Layout = React.createElement("UIListLayout", {
					Padding = UDim.new(0, 8),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}, props.children)
			else nil,
	})
end

return SectionPanel
