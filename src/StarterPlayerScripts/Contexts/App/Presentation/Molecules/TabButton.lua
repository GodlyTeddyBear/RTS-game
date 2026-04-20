--!strict
--[=[
	@class TabButton
	Themed tab switch button molecule with active/inactive gradient styling and hover animations.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local Frame = require(script.Parent.Parent.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Config.GradientTokens)
local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Application.Hooks.useHoverSpring)

local DEFAULT_FONT = "rbxasset://fonts/families/GothicA1.json"
local DEFAULT_GRADIENT_ROTATION = -4
local DEFAULT_LABEL_STROKE_THICKNESS = 2

export type TTabButtonProps = {
	Label: string,
	IsActive: boolean,
	LayoutOrder: number,
	OnSelect: () -> (),
	Width: UDim2,
	ActiveGradient: ColorSequence,
	ActiveDecoreStroke: ColorSequence,
	ActiveLabelStrokeColor: Color3,
	GradientRotation: number?,
	FontFamily: string?,
	LabelStrokeThickness: number?,
}

local function TabButton(props: TTabButtonProps)
	local isActive = props.IsActive
	local gradient = if isActive then props.ActiveGradient else GradientTokens.SLOT_GRADIENT
	local decoreStroke = if isActive then props.ActiveDecoreStroke else GradientTokens.SLOT_DECORE_STROKE
	local labelStrokeColor = if isActive then props.ActiveLabelStrokeColor else Color3.fromRGB(30, 30, 30)
	local gradientRotation = props.GradientRotation or DEFAULT_GRADIENT_ROTATION
	local fontFamily = props.FontFamily or DEFAULT_FONT
	local labelStrokeThickness = props.LabelStrokeThickness or DEFAULT_LABEL_STROKE_THICKNESS

	local buttonRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(buttonRef, AnimationTokens.Interaction.Tab)

	return e("TextButton", {
		ref = buttonRef,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Size = props.Width,
		LayoutOrder = props.LayoutOrder,
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(function()
			props.OnSelect()
		end),
	}, {
		UIGradient = e("UIGradient", {
			Color = gradient,
			Rotation = gradientRotation,
		}),

		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),

		Decore = e(Frame, {
			Size = UDim2.new(0.92683, 4, 0.75, 4),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			CornerRadius = UDim.new(0, 3),
			StrokeColor = decoreStroke,
			StrokeThickness = 2,
			StrokeMode = Enum.ApplyStrokeMode.Border,
		}),

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new(fontFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Interactable = false,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0.92683, 4, 0.75, 4),
			Text = props.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 16,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = labelStrokeColor,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = labelStrokeThickness,
			}),
		}),
	})
end

return TabButton
