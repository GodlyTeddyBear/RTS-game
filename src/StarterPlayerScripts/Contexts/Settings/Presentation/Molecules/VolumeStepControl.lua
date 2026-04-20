--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Contexts = script.Parent.Parent.Parent.Parent
local Button = require(Contexts.App.Presentation.Atoms.Button)
local Text = require(Contexts.App.Presentation.Atoms.Text)
local Colors = require(Contexts.App.Config.ColorTokens)

export type TVolumeStepControlProps = {
	Label: string,
	Value: number,
	DisplayValue: string,
	LayoutOrder: number?,
	OnDecrease: () -> (),
	OnIncrease: () -> (),
}

local function VolumeStepControl(props: TVolumeStepControlProps)
	return e("Frame", {
		Size = UDim2.fromScale(1, 0.135),
		BackgroundColor3 = Colors.Surface.Secondary,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Padding = e("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}),
		Label = e(Text, {
			Text = props.Label,
			Size = UDim2.fromScale(0.38, 1),
			LayoutOrder = 1,
			Variant = "label",
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
		}),
		Decrease = e(Button, {
			Text = "-",
			Size = UDim2.fromScale(0.12, 0.8),
			AnchorPoint = Vector2.new(0, 0),
			LayoutOrder = 2,
			Variant = "secondary",
			TextScaled = true,
			[React.Event.Activated] = props.OnDecrease,
		}),
		Value = e(Text, {
			Text = props.DisplayValue,
			Size = UDim2.fromScale(0.18, 1),
			LayoutOrder = 3,
			Variant = "body",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
		}),
		Increase = e(Button, {
			Text = "+",
			Size = UDim2.fromScale(0.12, 0.8),
			AnchorPoint = Vector2.new(0, 0),
			LayoutOrder = 4,
			Variant = "secondary",
			TextScaled = true,
			[React.Event.Activated] = props.OnIncrease,
		}),
	})
end

return VolumeStepControl
