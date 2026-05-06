--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

type TTextBlockProps = {
	LayoutOrder: number?,
	Text: string,
	TextColorStyle: Enum.StudioStyleGuideColor?,
}

local function TextBlock(props: TTextBlockProps)
	local theme = StudioComponents.useTheme()
	local textColorStyle = props.TextColorStyle or Enum.StudioStyleGuideColor.MainText

	return React.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = Enum.Font.SourceSans,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, 0),
		Text = props.Text,
		TextColor3 = theme:GetColor(textColorStyle),
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
end

return TextBlock
