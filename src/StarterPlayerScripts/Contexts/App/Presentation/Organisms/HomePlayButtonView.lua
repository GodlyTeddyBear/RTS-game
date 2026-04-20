--!strict
--[=[
	@class HomePlayButtonView
	Wrapper organism that connects the HomePlayButton to the home screen controller.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

export type THomePlayButtonViewProps = {
	isPlaying: boolean,
	buttonRef: { current: TextButton? },
	shimmerRef: { current: UIGradient? },
	onActivated: () -> (),
	onMouseEnter: () -> (),
	onMouseLeave: () -> (),
}

local function HomePlayButtonView(props: THomePlayButtonViewProps)
	return e("TextButton", {
		Name = "PlayButton",
		ref = props.buttonRef,
		Size = UDim2.fromOffset(280, 72),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(218, 179, 85),
		BackgroundTransparency = if props.isPlaying then 0.15 else 0,
		Text = if props.isPlaying then "LOADING..." else "PLAY",
		TextColor3 = Color3.fromRGB(12, 20, 46),
		Font = Enum.Font.Garamond,
		TextSize = 36,
		AutoButtonColor = false,
		[React.Event.Activated] = props.onActivated,
		[React.Event.MouseEnter] = props.onMouseEnter,
		[React.Event.MouseLeave] = props.onMouseLeave,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),
		Stroke = e("UIStroke", {
			Color = Color3.fromRGB(255, 230, 162),
			Thickness = 2,
			Transparency = 0.2,
		}),
		Shimmer = e("UIGradient", {
			ref = props.shimmerRef,
			Rotation = 30,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(208, 163, 72)),
				ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 232, 177)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(214, 171, 84)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(208, 163, 72)),
			}),
		}),
	})
end

return HomePlayButtonView
