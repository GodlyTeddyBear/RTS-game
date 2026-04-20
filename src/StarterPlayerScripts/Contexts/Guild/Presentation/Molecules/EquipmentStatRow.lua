--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local AdventurerEquipUiTokens = require(script.Parent.Parent.Parent.Config.AdventurerEquipUiTokens)

export type TEquipmentStatRowProps = {
	Label: string,
	Value: string,
	LayoutOrder: number?,
}

local function EquipmentStatRow(props: TEquipmentStatRowProps)
	return e("Frame", {
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.fromScale(1, 0.33),
	}, {
		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Position = UDim2.fromScale(0.36, 0.5),
			Size = UDim2.fromScale(0.6, 0.9),
			Text = props.Label .. ":",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = AdventurerEquipUiTokens.STAT_LABEL_SIZE,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Amount = e("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromScale(0.36, 0.9),
			Text = props.Value,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = AdventurerEquipUiTokens.STAT_VALUE_SIZE,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

return EquipmentStatRow
