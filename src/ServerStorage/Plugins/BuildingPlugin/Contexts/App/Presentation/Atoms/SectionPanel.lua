--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

type TSectionPanelProps = {
	Title: string,
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
			Label = React.createElement(StudioComponents.Label, {
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.new(1, -16, 1, 0),
				Text = props.Title,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColorStyle = Enum.StudioStyleGuideColor.BrightText,
			}),
		}),
		Body = React.createElement("Frame", {
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
		}, props.children),
	})
end

return SectionPanel
