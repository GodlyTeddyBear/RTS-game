--!strict
--[=[
	@class Button
	Themed text button atom with hover/press spring animations and optional gradient, stroke, and corner-radius overrides.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useState = React.useState
local useRef = React.useRef
local useEffect = React.useEffect

local GameEvents = require(ReplicatedStorage.Events.GameEvents)
local Events = GameEvents.Events
local useSpring = require(script.Parent.Parent.Parent.Application.Hooks.useSpring)
local useReducedMotion = require(script.Parent.Parent.Parent.Application.Hooks.useReducedMotion)
local ButtonHelpers = require(script.Parent.ButtonHelpers)

--[=[
	@type TButtonVariant ButtonHelpers.TButtonVariant
	@within Button
]=]
export type TButtonVariant = ButtonHelpers.TButtonVariant

--[=[
	@interface TButtonProps
	@within Button
	.Text string? -- Button label. Defaults to `"Button"`.
	.Size UDim2? -- Button size. Defaults to `UDim2.fromScale(0.25, 0.12)`.
	.Position UDim2? -- Button position.
	.AnchorPoint Vector2? -- Anchor point. Defaults to `Vector2.new(0.5, 0.5)`.
	.LayoutOrder number? -- Sort order within a layout.
	.Variant TButtonVariant? -- Visual style preset. Defaults to `"primary"`.
	.DisableAnimations boolean? -- When `true`, skips hover and press animations.
	.ClipsDescendants boolean? -- Passed through to the underlying `TextButton`.
	.Gradient ColorSequence? -- Optional `UIGradient` color applied to the background.
	.GradientRotation number? -- Rotation of the gradient in degrees.
	.StrokeColor ColorSequence? -- Optional `UIStroke` gradient color.
	.StrokeThickness number? -- Stroke thickness. Defaults to `3`.
	.StrokeMode Enum.ApplyStrokeMode? -- Stroke apply mode. Defaults to `Enum.ApplyStrokeMode.Border`.
	.StrokeBorderPosition Enum.BorderStrokePosition? -- Stroke border position.
	.CornerRadius UDim? -- Overrides the variant's default corner radius.
	.TextScaled boolean? -- Enables automatic text scaling for constrained layouts.
	.children any? -- Extra React children rendered inside the button.
]=]
export type TButtonProps = {
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Variant: TButtonVariant?,
	DisableAnimations: boolean?,
	ClipsDescendants: boolean?,
	-- Gradient support
	Gradient: ColorSequence?,
	GradientRotation: number?,
	-- Stroke support (renders UIStroke with optional gradient)
	StrokeColor: ColorSequence?,
	StrokeThickness: number?,
	StrokeMode: Enum.ApplyStrokeMode?,
	StrokeBorderPosition: Enum.BorderStrokePosition?,
	-- Corner radius override
	CornerRadius: UDim?,
	TextScaled: boolean?,
	-- Extra children to render inside the button
	children: any?,
	[any]: any,
}

--[=[
	Render a themed text button with hover/press spring animations and optional decorators.
	@within Button
	@param props TButtonProps -- Button configuration.
	@return React.Element -- The rendered `TextButton` element.
]=]
local function Button(props: TButtonProps)
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()

	local buttonRef = useRef(nil :: TextButton?)
	local uiScaleRef = useRef(nil :: UIScale?)
	local isHovered, setIsHovered = useState(false)
	local variantName = props.Variant or "primary"
	local variant = ButtonHelpers.BUTTON_VARIANTS[variantName]

	local shouldAnimate = not props.DisableAnimations and not prefersReducedMotion

	-- Create UIScale child for press animation
	useEffect(function()
		if not buttonRef.current then
			return
		end
		uiScaleRef.current = ButtonHelpers.ensureUIScale(buttonRef.current)

		-- Cleanup: remove the UIScale on unmount
		return function()
			if uiScaleRef.current and uiScaleRef.current.Parent then
				uiScaleRef.current:Destroy()
				uiScaleRef.current = nil
			end
		end
	end, {})

	-- Animate background color on hover (spring to hover color or back to default)
	useEffect(function()
		if not shouldAnimate or not buttonRef.current then
			return
		end

		-- Determine target color and transparency based on hover state
		local targetBg = if isHovered then variant.BackgroundHover else variant.BackgroundColor3
		local targetTransparency = if isHovered
			then variant.BackgroundHoverTransparency
			else variant.BackgroundTransparency

		-- Spring to target with responsive preset
		spring(buttonRef, {
			BackgroundColor3 = targetBg,
			BackgroundTransparency = targetTransparency,
		}, "Responsive")
	end, { isHovered, shouldAnimate, variantName } :: { any })

	-- Build child elements (UICorner, gradients, stroke, extra children)
	local children = {}

	-- Add corner radius styling
	children.UICorner = e("UICorner", {
		CornerRadius = props.CornerRadius or variant.CornerRadius,
	})

	-- Optionally add background gradient
	if props.Gradient then
		children.UIGradient = e("UIGradient", {
			Color = props.Gradient,
			Rotation = props.GradientRotation,
		})
	end

	-- Optionally add stroke with gradient
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

	-- Merge in any extra children provided
	if props.children then
		for key, child in props.children do
			children[key] = child
		end
	end

	return e("TextButton", {
		ref = buttonRef,
		Text = props.Text or "Button",
		TextColor3 = variant.TextColor3,
		Font = variant.Font,
		TextSize = variant.TextSize,
		TextScaled = props.TextScaled or false,
		BackgroundColor3 = variant.BackgroundColor3,
		BackgroundTransparency = variant.BackgroundTransparency,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(0.25, 0.12),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		LayoutOrder = props.LayoutOrder,
		ClipsDescendants = props.ClipsDescendants,
		[React.Event.MouseEnter] = function()
			setIsHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setIsHovered(false)
		end,
		[React.Event.Activated] = function(...)
			-- Emit UI event for tracking
			GameEvents.Bus:Emit(Events.UI.ButtonClicked, variantName)
			-- Play press animation (scale down then back up)
			ButtonHelpers.animatePressSpring(uiScaleRef, variant, shouldAnimate)
			-- Call user's callback if provided
			if props[React.Event.Activated] then
				props[React.Event.Activated](...)
			end
		end,
	}, children)
end

return Button
