--!strict
--[=[
	@class HomeScreenView
	Wrapper screen connecting HomeScreen to the home screen controller, managing state and animations.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useHomePlayButtonController = require(script.Parent.Parent.Parent.Application.Hooks.useHomePlayButtonController)
local Text = require(script.Parent.Parent.Atoms.Text)
local VStack = require(script.Parent.Parent.Layouts.VStack)

type THomeScreenViewProps = {
	containerRef: { current: Frame? },
	isPlaying: boolean,
	onPlayStart: () -> (),
	onPlayHover: (isHovered: boolean) -> (),
	onPlayComplete: () -> (),
}

local function HomeScreenView(props: THomeScreenViewProps)
	local playButton = useHomePlayButtonController(
		props.isPlaying,
		props.onPlayStart,
		props.onPlayHover,
		props.onPlayComplete
	)

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
			Panel = e("Frame", {
				Size = UDim2.fromScale(0.46, 0.4),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(16, 21, 36),
				BackgroundTransparency = 0.08,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 18),
				}),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(72, 102, 160),
					Thickness = 2,
					Transparency = 0.35,
				}),
				Layout = e(VStack, {
					Size = UDim2.fromScale(1, 1),
					Gap = 18,
					Align = "Center",
					Justify = "Center",
					BackgroundTransparency = 1,
					Padding = 20,
				}, {
					Title = e(Text, {
						Size = UDim2.fromScale(1, 0.22),
						Text = "Untitled Incremental",
						Variant = "heading",
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					Subtitle = e(Text, {
						Size = UDim2.fromScale(1, 0.14),
						Text = "Press play to enter the game screen.",
						Variant = "body",
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
					}),
					PlayButton = e("TextButton", {
						ref = playButton.buttonRef,
						Size = UDim2.fromScale(0.52, 0.22),
						BackgroundColor3 = Color3.fromRGB(28, 47, 93),
						BorderSizePixel = 0,
						AutoButtonColor = false,
						ClipsDescendants = true,
						Text = if props.isPlaying then "Opening..." else "Enter Game",
						Font = Enum.Font.GothamBold,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextSize = 24,
						[React.Event.Activated] = playButton.onActivated,
						[React.Event.MouseEnter] = playButton.onMouseEnter,
						[React.Event.MouseLeave] = playButton.onMouseLeave,
					}, {
						Corner = e("UICorner", {
							CornerRadius = UDim.new(0, 16),
						}),
						Stroke = e("UIStroke", {
							Color = Color3.fromRGB(120, 173, 255),
							Thickness = 2,
							Transparency = 0.2,
						}),
						Shimmer = e("UIGradient", {
							ref = playButton.shimmerRef,
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
								ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
							}),
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0.4),
								NumberSequenceKeypoint.new(0.5, 0),
								NumberSequenceKeypoint.new(1, 0.4),
							}),
						}),
					}),
				}),
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
