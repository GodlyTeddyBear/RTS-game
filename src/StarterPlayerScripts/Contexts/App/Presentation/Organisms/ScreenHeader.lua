--!strict
--[=[
	@class ScreenHeader
	Organism displaying a screen title, subtitle, and optional go-back button in a row layout.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Atoms.Frame)
local IconButton = require(script.Parent.Parent.Atoms.IconButton)
local GradientTokens = require(script.Parent.Parent.Parent.Config.GradientTokens)

local DEFAULT_FONT = "rbxasset://fonts/families/GothicA1.json"
local DEFAULT_HEIGHT = UDim2.fromScale(1, 0.098)

export type TScreenHeaderProps = {
	Title: string,
	OnBack: () -> (),
	Height: UDim2?,
	FontFamily: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	children: any?,
}

local function ScreenHeader(props: TScreenHeaderProps)
	local height = props.Height or DEFAULT_HEIGHT
	local fontFamily = props.FontFamily or DEFAULT_FONT

	local children: { [string]: any } = {
		BackButton = e(IconButton, {
			Icon = "back",
			ImageId = GradientTokens.ICON_BACK_ARROW,
			ImageColor3 = Color3.new(1, 1, 1),
			ImageSize = UDim2.fromScale(0.45, 0.6),
			Position = UDim2.new(0.175, -6, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(0.04653, 12, 0.5, 12),
			Variant = "ghost",
			Gradient = GradientTokens.BUTTON_GRADIENT,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 6,
			CornerRadius = UDim.new(0, 0),
			ClipsDescendants = true,
			[React.Event.Activated] = props.OnBack,
		}),

		TitleText = e("TextLabel", {
			Text = props.Title,
			FontFace = Font.new(fontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 50,
			TextWrapped = true,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.37917, 0.5),
			Size = UDim2.new(0.24167, 6, 0.3, 6),
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(21, 20, 20),
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 3,
			}),
		}),
	}

	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return e(Frame, {
		Size = height,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0,
		Gradient = GradientTokens.BAR_GRADIENT,
		StrokeColor = GradientTokens.GOLD_STROKE,
		StrokeThickness = 4,
		StrokeMode = Enum.ApplyStrokeMode.Border,
		StrokeBorderPosition = Enum.BorderStrokePosition.Inner,
		LayoutOrder = 1,
		ClipsDescendants = true,
		children = children,
	})
end

return ScreenHeader
