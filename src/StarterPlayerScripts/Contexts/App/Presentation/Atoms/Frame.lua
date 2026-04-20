--!strict
--[=[
	@class Frame
	Flexible frame atom supporting gradient, stroke, corner-radius, and size/position customization.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

--[=[
	@interface TFrameProps
	@within Frame
	.Size UDim2? -- Frame size. Defaults to `UDim2.fromScale(1, 1)`.
	.Position UDim2? -- Frame position.
	.AnchorPoint Vector2? -- Anchor point. Defaults to `Vector2.new(0.5, 0.5)`.
	.BackgroundTransparency number? -- Background transparency. Defaults to `1`.
	.BackgroundColor3 Color3? -- Background colour.
	.BorderSizePixel number? -- Border size. Defaults to `0`.
	.LayoutOrder number? -- Sort order within a layout.
	.AutomaticSize Enum.AutomaticSize? -- Auto-sizing mode.
	.ClipsDescendants boolean? -- Whether to clip child elements.
	.Gradient ColorSequence? -- Optional `UIGradient` colour applied to the background.
	.GradientRotation number? -- Rotation of the gradient in degrees.
	.StrokeColor ColorSequence? -- Optional `UIStroke` gradient colour.
	.StrokeThickness number? -- Stroke thickness. Defaults to `3`.
	.StrokeMode Enum.ApplyStrokeMode? -- Stroke apply mode. Defaults to `Enum.ApplyStrokeMode.Border`.
	.StrokeBorderPosition Enum.BorderStrokePosition? -- Stroke border position.
	.CornerRadius UDim? -- Corner radius for the frame's `UICorner`.
	.ZIndex number? -- Z-index for layering.
	.children any? -- Extra React children rendered inside the frame.
]=]
export type TFrameProps = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	BackgroundTransparency: number?,
	BackgroundColor3: Color3?,
	BorderSizePixel: number?,
	LayoutOrder: number?,
	AutomaticSize: Enum.AutomaticSize?,
	ClipsDescendants: boolean?,
	-- Gradient support
	Gradient: ColorSequence?,
	GradientRotation: number?,
	-- Stroke support (renders UIStroke with optional gradient)
	StrokeColor: ColorSequence?,
	StrokeThickness: number?,
	StrokeMode: Enum.ApplyStrokeMode?,
	StrokeBorderPosition: Enum.BorderStrokePosition?,
	-- Corner radius
	CornerRadius: UDim?,
	ZIndex: number?,
	children: any?,
}

--[=[
	Render a flexible frame with optional gradient, stroke, corner-radius, and size/position customization.
	@within Frame
	@param props TFrameProps -- Frame configuration.
	@return React.Element -- The rendered `Frame` element.
]=]
local function Frame(props: TFrameProps)
	-- Build children table with decorators + user children
	local children = {}

	if props.Gradient then
		children.UIGradient = e("UIGradient", {
			Color = props.Gradient,
			Rotation = props.GradientRotation,
		})
	end

	if props.StrokeColor then
		children.UIStroke = e("UIStroke", {
			ApplyStrokeMode = props.StrokeMode or Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = props.StrokeBorderPosition,
			Color = Color3.new(1, 1, 1),
			Thickness = props.StrokeThickness or 3,
		}, {
			UIGradient = e("UIGradient", {
				Color = props.StrokeColor,
			}),
		})
	end

	if props.CornerRadius then
		children.UICorner = e("UICorner", {
			CornerRadius = props.CornerRadius,
		})
	end

	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return e("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundTransparency = props.BackgroundTransparency or 1,
		BackgroundColor3 = props.BackgroundColor3,
		BorderSizePixel = props.BorderSizePixel or 0,
		LayoutOrder = props.LayoutOrder,
		AutomaticSize = props.AutomaticSize,
		ClipsDescendants = props.ClipsDescendants,
		ZIndex = props.ZIndex,
	}, children)
end

return Frame
