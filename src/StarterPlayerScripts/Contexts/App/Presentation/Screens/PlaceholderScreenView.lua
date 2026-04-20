--!strict
--[=[
	@class PlaceholderScreenView
	Wrapper screen connecting PlaceholderScreen to transition animations.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local VStack = require(script.Parent.Parent.Layouts.VStack)
local Button = require(script.Parent.Parent.Atoms.Button)
local Text = require(script.Parent.Parent.Atoms.Text)

export type TPlaceholderScreenViewProps = {
	containerRef: { current: Frame? },
	title: string,
	description: string?,
	onBack: () -> (),
}

local function PlaceholderScreenView(props: TPlaceholderScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}, {
		Content = e(VStack, {
			Size = UDim2.fromScale(1, 1),
			Bg = "Surface.Primary",
			Align = "Center",
			Justify = "Center",
			Gap = 16,
		}, {
			TitleText = e(Text, {
				Text = props.title,
				Variant = "heading",
				Size = UDim2.fromScale(0.8, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 1,
			}),
			DescriptionText = props.description and e(Text, {
				Text = props.description,
				Variant = "body",
				Size = UDim2.fromScale(0.8, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 2,
			}) or nil,
			BackButton = e(Button, {
				Text = "← Back to Game",
				Size = UDim2.fromOffset(200, 50),
				Variant = "primary",
				LayoutOrder = 3,
				[React.Event.Activated] = props.onBack,
			}),
		}),
	})
end

return PlaceholderScreenView
