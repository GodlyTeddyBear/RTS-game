--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local ColorTokens = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local TypographyTokens = require(script.Parent.Parent.Parent.Parent.App.Config.TypographyTokens)

-- Gradient rotation angle shared across slot and detail panel icon areas.
local GRADIENT_ROTATION = -141

--[=[
	@interface TItemIconDisplayProps
	@within ItemIconDisplay
	.Icon string? -- Asset URI for the item icon image; nil renders the abbreviation fallback
	.NameAbbreviation string -- Two-character abbreviation shown when no icon is available
	.Position UDim2? -- Position of the icon frame (defaults to centered)
	.Size UDim2? -- Size of the icon frame
	.StrokeThickness number? -- UIStroke thickness (defaults to 6)
	.StrokeGradient ColorSequence? -- UIStroke gradient (defaults to DETAIL_ICON_STROKE)
]=]
export type TItemIconDisplayProps = {
	Icon: string?,
	NameAbbreviation: string,
	Position: UDim2?,
	Size: UDim2?,
	StrokeThickness: number?,
	StrokeGradient: ColorSequence?,
}

--[=[
	@class ItemIconDisplay
	Reusable icon display molecule for shop items. Renders a gradient-backed frame with the item image or a name abbreviation fallback.
	@client
]=]

--[=[
	Render a shop item icon with gradient background, stroke, and image or text fallback.
	@within ItemIconDisplay
	@param props TItemIconDisplayProps
	@return React.ReactElement -- Icon display frame
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

		UIStroke = if props.StrokeGradient
			then e("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.new(1, 1, 1),
				Thickness = props.StrokeThickness or 6,
			}, {
				UIGradient = e("UIGradient", {
					Color = props.StrokeGradient,
					Rotation = GRADIENT_ROTATION,
				}),
			})
			else nil,

		UICorner = e("UICorner"),

		IconImage = if props.Icon
			then e("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = props.Icon,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.85, 0.85),
				ScaleType = Enum.ScaleType.Fit,
			})
			else nil,

		IconText = if not props.Icon
			then e("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = props.NameAbbreviation,
				TextColor3 = ColorTokens.Text.Muted,
				TextScaled = true,
				FontFace = TypographyTokens.FontFace.Bold,
			})
			else nil,
	})
end

return ItemIconDisplay
