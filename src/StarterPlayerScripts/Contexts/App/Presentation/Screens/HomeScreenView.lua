--!strict
--[=[
	@class HomeScreenView
	Wrapper screen connecting HomeScreen to the home screen controller, managing state and animations.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local HomePlayButton = require(script.Parent.Parent.Organisms.HomePlayButton)

type THomeScreenViewProps = {
	containerRef: { current: Frame? },
	isPlaying: boolean,
	onPlayStart: () -> (),
	onPlayHover: (isHovered: boolean) -> (),
	onPlayComplete: () -> (),
}

local function HomeScreenView(props: THomeScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(6, 12, 30),
		BackgroundTransparency = 0.2,
	}, {
		Content = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			Title = e("TextLabel", {
				Name = "Title",
				Size = UDim2.fromScale(0.6, 0.12),
				Position = UDim2.fromScale(0.5, 0.22),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Text = "Untitled Incremental",
				Font = Enum.Font.Garamond,
				TextColor3 = Color3.fromRGB(234, 199, 116),
				TextStrokeTransparency = 0.7,
				TextScaled = true,
			}),
			PlayButton = e(HomePlayButton, {
				isPlaying = props.isPlaying,
				onPlayStart = props.onPlayStart,
				onPlayHover = props.onPlayHover,
				onPlayComplete = props.onPlayComplete,
			}),
			Version = e("TextLabel", {
				Size = UDim2.fromOffset(200, 24),
				Position = UDim2.fromScale(0.985, 0.975),
				AnchorPoint = Vector2.new(1, 1),
				BackgroundTransparency = 1,
				Text = "v0.1.0 alpha",
				Font = Enum.Font.Gotham,
				TextColor3 = Color3.fromRGB(173, 181, 214),
				TextTransparency = 0.2,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
	})
end

return HomeScreenView
