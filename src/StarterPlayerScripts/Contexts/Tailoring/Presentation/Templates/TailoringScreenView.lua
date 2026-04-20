--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local IconButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.IconButton)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

type TTailoringScreenViewProps = {
	containerRef: { current: Frame? },
	recipeCount: number,
	scrollChildren: { [string]: any },
	onBack: () -> (),
}

local function TailoringScreenView(props: TTailoringScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		Header = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.049),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.098),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.BAR_GRADIENT,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
			LayoutOrder = 1,
			ZIndex = 4,
			ClipsDescendants = true,
			children = {
				BackButton = e(IconButton, {
					Icon = "back",
					ImageId = GradientTokens.ICON_BACK_ARROW,
					ImageColor3 = Color3.new(1, 1, 1),
					ImageSize = UDim2.fromScale(0.45, 0.6),
					Position = UDim2.new(0.175, -6, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Size = UDim2.fromScale(0.07, 0.8),
					Variant = "ghost",
					Gradient = GradientTokens.BUTTON_GRADIENT,
					StrokeColor = GradientTokens.GOLD_STROKE,
					StrokeThickness = 2.5,
					CornerRadius = UDim.new(0, 0),
					ClipsDescendants = true,
					[React.Event.Activated] = props.onBack,
				}),
				TitleText = e("TextLabel", {
					Text = "Tailoring",
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 50,
					TextWrapped = true,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.37917, 0.5),
					Size = UDim2.fromScale(0.167, 0.3),
				}, {
					UIStroke = e("UIStroke", {
						Color = Color3.fromRGB(21, 20, 20),
						LineJoinMode = Enum.LineJoinMode.Miter,
						Thickness = 3,
					}),
				}),
			},
		}),
		TabBar = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.12779),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.06),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.BAR_GRADIENT,
			LayoutOrder = 2,
			ZIndex = 3,
			children = {
				Label = e("TextLabel", {
					Text = "Recipes:",
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Right,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.07, 0.5),
					Position = UDim2.fromScale(0.031, 0.49),
					Size = UDim2.fromScale(0.092, 0.49),
				}),
				Amount = e("TextLabel", {
					Text = tostring(props.recipeCount),
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json"),
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 25,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.18, 0.5),
					Position = UDim2.fromScale(0.146, 0.49),
					Size = UDim2.fromScale(0.099, 0.49),
				}),
			},
		}),
		Content = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.53826),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.762),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 18)),
				ColorSequenceKeypoint.new(0.481, Color3.fromRGB(30, 27, 35)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(33, 32, 32)),
			}),
			GradientRotation = -16,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			LayoutOrder = 3,
			ZIndex = 5,
			ClipsDescendants = true,
			children = {
				ContainerScroll = e("ScrollingFrame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					CanvasSize = UDim2.new(),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.977, 0.96),
					ScrollBarThickness = 4,
					ScrollBarImageColor3 = Color3.fromRGB(255, 204, 0),
					ClipsDescendants = true,
				}, props.scrollChildren),
			},
		}),
		Footer = e(Frame, {
			Position = UDim2.fromScale(0.5, 0.95948),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromScale(1, 0.081),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.BAR_GRADIENT,
			LayoutOrder = 4,
			ZIndex = 0,
		}),
	})
end

return TailoringScreenView
