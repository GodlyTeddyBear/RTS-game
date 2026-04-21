--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local VStack = require(script.Parent.Parent.Parent.Parent.App.Presentation.Layouts.VStack)

export type TResultsScreenViewProps = {
	containerRef: { current: Frame? },
	waveNumber: number,
	score: number,
	onPlayAgain: () -> (),
}

local function ResultsScreenView(props: TResultsScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(8, 10, 20),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, {
		Content = e("Frame", {
			Name = "Content",
			Size = UDim2.fromScale(0.46, 0.42),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(20, 24, 38),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 12),
			}),
			Layout = e(VStack, {
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Gap = 14,
				Align = "Center",
				Justify = "Center",
				BackgroundTransparency = 1,
				Padding = 18,
			}, {
				Title = e(Text, {
					Size = UDim2.fromScale(1, 0.2),
					Text = "Run Over",
					Variant = "heading",
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
				Wave = e(Text, {
					Size = UDim2.fromScale(1, 0.16),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Text = ("Wave reached: %d"):format(props.waveNumber),
					Variant = "body",
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
				Score = e(Text, {
					Size = UDim2.fromScale(1, 0.16),
					Text = ("Score: %d"):format(props.score),
					Variant = "body",
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
				PlayAgain = e(Button, {
					Size = UDim2.fromScale(0.42, 0.2),
					Text = "Play Again",
					Variant = "primary",
					[React.Event.Activated] = props.onPlayAgain,
				}),
			}),
		}),
	})
end

return ResultsScreenView
