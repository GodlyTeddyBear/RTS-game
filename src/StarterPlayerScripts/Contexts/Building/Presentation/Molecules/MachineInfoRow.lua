--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local e = React.createElement

local PANEL_TEXT = Colors.NPC.PanelText
local PANEL_SUBTLE = Colors.NPC.PanelSubtle
local PANEL_HEADER = Colors.NPC.PanelHeaderDark

export type TMachineInfoRowProps = {
	layoutOrder: number,
	leftText: string,
	rightText: string,
	leftVariant: "heading" | "label" | "body" | "caption",
	rightVariant: "heading" | "label" | "body" | "caption",
	leftColor: Color3?,
	rightColor: Color3?,
	leftWidthScale: number?,
}

local function MachineInfoRow(props: TMachineInfoRowProps)
	local leftWidthScale = props.leftWidthScale or 0.7
	local rightWidthScale = 1 - leftWidthScale

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0.3),
		BackgroundColor3 = PANEL_HEADER,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0.16, 0),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
		}),
		Name = e(Text, {
			Text = props.leftText,
			Variant = props.leftVariant,
			TextScaled = true,
			Size = UDim2.fromScale(leftWidthScale, 1),
			TextColor3 = props.leftColor or PANEL_TEXT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		Value = e(Text, {
			Text = props.rightText,
			Variant = props.rightVariant,
			TextScaled = true,
			Size = UDim2.fromScale(rightWidthScale, 1),
			Position = UDim2.fromScale(leftWidthScale, 0),
			TextColor3 = props.rightColor or PANEL_SUBTLE,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return MachineInfoRow
