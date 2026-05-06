--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local StudioComponents = require(ReplicatedStorage.Packages.StudioComponents)

type TStatusBarProps = {
	Message: string,
	Tone: string,
}

local function getTextColorStyle(tone: string)
	if tone == "Error" then
		return Enum.StudioStyleGuideColor.ErrorText
	end

	if tone == "Success" then
		return Enum.StudioStyleGuideColor.DialogMainButtonText
	end

	return Enum.StudioStyleGuideColor.MainText
end

local function StatusBar(props: TStatusBarProps)
	local theme = StudioComponents.useTheme()

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 28),
	}, {
		Label = React.createElement(StudioComponents.Label, {
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Text = props.Message,
			TextColorStyle = getTextColorStyle(props.Tone),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return StatusBar
