--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Contexts = script.Parent.Parent.Parent.Parent
local Button = require(Contexts.App.Presentation.Atoms.Button)
local Text = require(Contexts.App.Presentation.Atoms.Text)
local Colors = require(Contexts.App.Config.ColorTokens)

export type TSoundEnabledToggleProps = {
	Enabled: boolean,
	LayoutOrder: number?,
	OnToggle: () -> (),
}

local function SoundEnabledToggle(props: TSoundEnabledToggleProps)
	local statusText = if props.Enabled then "On" else "Off"
	local detailText = if props.Enabled then "Sound is enabled" else "Sound is muted"

	return e("Frame", {
		Size = UDim2.fromScale(1, 0.145),
		BackgroundColor3 = Colors.Surface.Tertiary,
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
			Padding = UDim.new(0, 16),
		}),
		Copy = e("Frame", {
			Size = UDim2.fromScale(0.7, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2),
			}),
			Title = e(Text, {
				Text = "All Sound",
				Size = UDim2.fromScale(1, 0.45),
				LayoutOrder = 1,
				Variant = "label",
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Detail = e(Text, {
				Text = detailText,
				Size = UDim2.fromScale(1, 0.35),
				LayoutOrder = 2,
				Variant = "caption",
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
		Toggle = e(Button, {
			Text = statusText,
			Size = UDim2.fromScale(0.22, 0.8),
			AnchorPoint = Vector2.new(0, 0),
			LayoutOrder = 2,
			Variant = if props.Enabled then "primary" else "secondary",
			TextScaled = true,
			[React.Event.Activated] = props.OnToggle,
		}),
	})
end

return SoundEnabledToggle
