--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

local GRADIENT_ROTATION = -141

--[=[
	@interface TItemIconDisplayProps
	@within ItemIconDisplay
	.ItemIcon string? -- Asset path; nil shows the NameAbbr fallback text
	.NameAbbr string -- 2-letter fallback when no icon is available
	.Position UDim2 -- Icon frame position
	.Size UDim2 -- Icon frame size
	.StrokeColor ColorSequence? -- Optional UIStroke gradient (detail panel only)
	.StrokeThickness number? -- Stroke thickness (detail panel only)
]=]
export type TItemIconDisplayProps = {
	ItemIcon: string?,
	NameAbbr: string,
	Position: UDim2,
	Size: UDim2,
	StrokeColor: ColorSequence?,
	StrokeThickness: number?,
}

--[=[
	@function ItemIconDisplay
	@within ItemIconDisplay
	Gradient icon frame shared by the slot cell and detail panel.
	Shows the item image when available, falls back to a 2-letter abbreviation.
	@param props TItemIconDisplayProps
	@return React.ReactElement
]=]
local function ItemIconDisplay(props: TItemIconDisplayProps)
	return e("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		Position = props.Position,
		Size = props.Size,
	}, {
		UIGradient = e("UIGradient", {
			Color = GradientTokens.SLOT_ICON_GRADIENT,
			Rotation = GRADIENT_ROTATION,
		}),
		UIStroke = if props.StrokeColor
			then e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = props.StrokeThickness or 3,
			}, {
				UIGradient = e("UIGradient", {
					Color = props.StrokeColor,
					Rotation = GRADIENT_ROTATION,
				}),
			})
			else nil,
		UICorner = e("UICorner"),
		IconImage = if props.ItemIcon
			then e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = props.ItemIcon,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.85, 0.85),
				ScaleType = Enum.ScaleType.Fit,
			})
			else nil,
		IconText = if not props.ItemIcon
			then e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.NameAbbr,
				TextColor3 = ColorTokens.Text.Muted,
				TextScaled = true,
				FontFace = TypographyTokens.FontFace.Bold,
			})
			else nil,
	})
end

return ItemIconDisplay
