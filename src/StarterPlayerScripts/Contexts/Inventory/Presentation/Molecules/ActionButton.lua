--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

--[=[
	@interface TActionButtonProps
	@within ActionButton
	.Label string -- Button label text
	.Size UDim2 -- Button size
	.Position UDim2 -- Button position
	.AnchorPoint Vector2? -- Anchor point (defaults to center)
	.ButtonRef { current: TextButton? }? -- Ref for animation targeting
	.OnMouseEnter (() -> ())? -- Hover enter handler
	.OnMouseLeave (() -> ())? -- Hover leave handler
	.OnActivated (() -> ())? -- Click handler
]=]
export type TActionButtonProps = {
	Label: string,
	Size: UDim2,
	Position: UDim2,
	AnchorPoint: Vector2?,
	ButtonRef: { current: TextButton? }?,
	OnMouseEnter: (() -> ())?,
	OnMouseLeave: (() -> ())?,
	OnActivated: (() -> ())?,
}

--[=[
	@function ActionButton
	@within ActionButton
	Green action button with gradient fill, inner decore stroke, and bold label.
	Used in ItemDetailPanel and InventoryFooter.
	@param props TActionButtonProps
	@return React.ReactElement
]=]
local function ActionButton(props: TActionButtonProps)
	return e("TextButton", {
		ref = props.ButtonRef,
		Visible = false,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = props.Position,
		Size = props.Size,
		Text = "",
		TextSize = 1,
		[React.Event.MouseEnter] = props.OnMouseEnter,
		[React.Event.MouseLeave] = props.OnMouseLeave,
		[React.Event.Activated] = props.OnActivated,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.GREEN_ACTION_GRADIENT,
			Rotation = -3,
		}),
		UICorner = e("UICorner"),
		Decore = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(0.49597, 0.4902),
			Size = UDim2.fromScale(0.91129, 0.82353),
		}, {
			UIStroke = e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				Color = GradientTokens.GREEN_ACTION_DECORE_COLOR,
				Thickness = 2,
			}),
			UICorner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),
		Label = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = TypographyTokens.FontFace.Bold,
			Interactable = false,
			Position = UDim2.fromScale(0.49597, 0.4902),
			Size = UDim2.new(0.91129, 4, 0.58824, 4),
			Text = props.Label,
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 14,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = GradientTokens.GREEN_ACTION_LABEL_STROKE_COLOR,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Thickness = 2,
			}),
		}),
	})
end

return ActionButton
