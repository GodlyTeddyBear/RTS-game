--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local useRef = React.useRef

local AnimationTokens = require(script.Parent.Parent.Parent.Parent.App.Config.AnimationTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)
local useHoverSpring = require(script.Parent.Parent.Parent.Parent.App.Application.Hooks.useHoverSpring)

--[=[
	@interface TActionButtonProps
	Props for the shop action button (buy or sell variant).
	.Label string -- Button label text
	.Gradient ColorSequence -- Background gradient
	.DecoreColor Color3 -- Inner decore stroke color
	.DecoreStrokeGradient ColorSequence? -- Inner decore stroke gradient (optional)
	.LabelStrokeColor Color3 -- Label UIStroke color
	.LabelStrokeGradient ColorSequence? -- Label UIStroke gradient (optional)
	.GradientRotation number -- Rotation applied to the background gradient
	.OnActivated () -> () -- Action callback
]=]
export type TActionButtonProps = {
	Label: string,
	Gradient: ColorSequence,
	DecoreColor: Color3,
	DecoreStrokeGradient: ColorSequence?,
	LabelStrokeColor: Color3,
	LabelStrokeGradient: ColorSequence?,
	GradientRotation: number,
	OnActivated: () -> (),
}

--[=[
	@class ActionButton
	Generic action button for the shop detail panel. Supports buy and sell variants via gradient/color props.
	@client
]=]

--[=[
	Render a shop action button with hover animation.
	@within ActionButton
	@param props TActionButtonProps
	@return React.ReactElement -- Action button component
]=]
local function ActionButton(props: TActionButtonProps)
	local btnRef = useRef(nil :: TextButton?)
	local hover = useHoverSpring(btnRef, AnimationTokens.Interaction.ActionButton)

	return e("TextButton", {
		ref = btnRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		LayoutOrder = 1,
		Position = UDim2.fromScale(0.5, 0.50769),
		Size = UDim2.fromScale(0.42553, 0.92308),
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(props.OnActivated),
	}, {
		UIGradient = e("UIGradient", {
			Color = props.Gradient,
			Rotation = props.GradientRotation,
		}),

		UICorner = e("UICorner"),

		Decore = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.49167, 0.5),
			Size = UDim2.fromScale(0.88333, 0.86667),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = props.DecoreColor,
				Thickness = 2,
			}, if props.DecoreStrokeGradient
				then {
					UIGradient = e("UIGradient", {
						Color = props.DecoreStrokeGradient,
					}),
				}
				else nil),

			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),

		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Bold,
			Interactable = false,
			LayoutOrder = 1,
			Position = UDim2.fromScale(0.5, 0.48333),
			Size = UDim2.new(0.83333, 4, 0.86667, 4),
			Text = props.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 14,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = props.LabelStrokeColor,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 2,
			}, if props.LabelStrokeGradient
				then {
					UIGradient = e("UIGradient", {
						Color = props.LabelStrokeGradient,
					}),
				}
				else nil),
		}),
	})
end

return ActionButton
