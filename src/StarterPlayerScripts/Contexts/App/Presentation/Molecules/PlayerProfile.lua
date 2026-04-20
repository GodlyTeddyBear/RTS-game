--!strict
--[=[
	@class PlayerProfile
	Molecule displaying player name and level badge with themed text styling.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Colors = require(script.Parent.Parent.Parent.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Config.TypographyTokens)

export type TPlayerProfileProps = {
	Username: string,
	Level: number,
	LayoutOrder: number?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Size: UDim2?,
}

local function PlayerProfile(props: TPlayerProfileProps)
	return e("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size or UDim2.fromScale(0.167, 0.607),
	}, {
		NameLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Typography.Font.Bold,
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromScale(1, 0.33),
			Text = props.Username,
			TextColor3 = Colors.Text.Primary,
			TextSize = Typography.FontSize.H3,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),

		LevelLabel = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Typography.Font.Body,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5, 0.72),
			Size = UDim2.fromScale(1, 0.319),
			Text = "Level " .. tostring(props.Level),
			TextColor3 = Colors.Text.Primary,
			TextSize = Typography.FontSize.Body,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})
end

return PlayerProfile
