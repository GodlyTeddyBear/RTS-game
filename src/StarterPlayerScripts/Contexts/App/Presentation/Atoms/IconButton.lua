--!strict
--[=[
	@class IconButton
	Themed icon-only button atom that renders a Unicode character or `ImageLabel`, with hover/press spring animations and optional decorators.
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
local Typography = require(script.Parent.Parent.Parent.Config.TypographyTokens)

--[=[
	@type TButtonVariant ButtonHelpers.TButtonVariant
	@within IconButton
]=]
export type TButtonVariant = ButtonHelpers.TButtonVariant

--[=[
	@interface TIconButtonProps
	@within IconButton
	.Icon string -- Unicode key from the built-in icon map (`"menu"`, `"settings"`, `"close"`, `"back"`) or a literal character.
	.Size UDim2? -- Button size. Defaults to `UDim2.fromScale(0.1, 0.8)`.
	.Position UDim2? -- Button position.
	.AnchorPoint Vector2? -- Anchor point. Defaults to `Vector2.new(0.5, 0.5)`.
	.LayoutOrder number? -- Sort order within a layout.
	.Variant TButtonVariant? -- Visual style preset. Defaults to `"ghost"`.
	.DisableAnimations boolean? -- When `true`, skips hover and press animations.
	.ClipsDescendants boolean? -- Passed through to the underlying `TextButton`.
	.ImageId string? -- Asset ID for image-based icon; when set, renders an `ImageLabel` instead of text.
	.ImageColor3 Color3? -- Tint colour for the image icon. Defaults to `Color3.fromRGB(217, 217, 217)`.
	.ImageSize UDim2? -- Size of the inner `ImageLabel`. Defaults to `UDim2.fromScale(0.75, 0.75)`.
	.Gradient ColorSequence? -- Optional `UIGradient` color applied to the background.
	.GradientRotation number? -- Rotation of the gradient in degrees.
	.StrokeColor ColorSequence? -- Optional `UIStroke` gradient color.
	.StrokeThickness number? -- Stroke thickness. Defaults to `3`.
	.StrokeMode Enum.ApplyStrokeMode? -- Stroke apply mode. Defaults to `Enum.ApplyStrokeMode.Border`.
	.StrokeBorderPosition Enum.BorderStrokePosition? -- Stroke border position.
	.CornerRadius UDim? -- Overrides the variant's default corner radius.
]=]
export type TIconButtonProps = {
	Icon: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Variant: TButtonVariant?,
	DisableAnimations: boolean?,
	ClipsDescendants: boolean?,
	-- Image-based icon (renders ImageLabel instead of text character)
	ImageId: string?,
	ImageColor3: Color3?,
	ImageSize: UDim2?,
	-- Gradient support
	Gradient: ColorSequence?,
	GradientRotation: number?,
	-- Stroke support
	StrokeColor: ColorSequence?,
	StrokeThickness: number?,
	StrokeMode: Enum.ApplyStrokeMode?,
	StrokeBorderPosition: Enum.BorderStrokePosition?,
	-- Corner radius override
	CornerRadius: UDim?,
	[any]: any,
}

-- Icon mapping using Unicode characters
local ICONS = {
	menu = "☰",
	settings = "⚙",
	close = "✕",
	back = "←",
}

--[=[
	Render a themed icon-only button with hover/press spring animations and optional image, gradient, and stroke decorators.
	@within IconButton
	@param props TIconButtonProps -- Icon button configuration.
	@return React.Element -- The rendered `TextButton` element.
]=]
local function IconButton(props: TIconButtonProps)
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()

	local buttonRef = useRef(nil :: TextButton?)
	local uiScaleRef = useRef(nil :: UIScale?)
	local isHovered, setIsHovered = useState(false)
	local variantName = props.Variant or "ghost"
	local variant = ButtonHelpers.BUTTON_VARIANTS[variantName]

	local iconChar = ICONS[props.Icon] or props.Icon
	local shouldAnimate = not props.DisableAnimations and not prefersReducedMotion
	local useImage = props.ImageId ~= nil

	-- Ensure UIScale child exists for press animation
	useEffect(function()
		if not buttonRef.current then
			return
		end
		uiScaleRef.current = ButtonHelpers.ensureUIScale(buttonRef.current)
		return function()
			if uiScaleRef.current and uiScaleRef.current.Parent then
				uiScaleRef.current:Destroy()
				uiScaleRef.current = nil
			end
		end
	end, {})

	-- Animate hover color transition
	useEffect(function()
		if not shouldAnimate or not buttonRef.current then
			return
		end
		local targetBg = if isHovered then variant.BackgroundHover else variant.BackgroundColor3
		local targetTransparency = if isHovered
			then variant.BackgroundHoverTransparency
			else variant.BackgroundTransparency
		spring(buttonRef, {
			BackgroundColor3 = targetBg,
			BackgroundTransparency = targetTransparency,
		}, "Responsive")
	end, { isHovered, shouldAnimate } :: { any })

	-- Build children table
	local children = {}

	children.UICorner = e("UICorner", {
		CornerRadius = props.CornerRadius or variant.CornerRadius,
	})

	if useImage then
		children.IconImage = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = props.ImageId,
			ImageColor3 = props.ImageColor3 or Color3.fromRGB(217, 217, 217),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = props.ImageSize or UDim2.fromScale(0.75, 0.75),
		})
	end

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

	return e("TextButton", {
		ref = buttonRef,
		Text = if useImage then "" else iconChar,
		TextColor3 = variant.TextColor3,
		Font = Typography.Font.Heading,
		TextSize = if useImage then 1 else Typography.FontSize.Body,
		BackgroundColor3 = variant.BackgroundColor3,
		BackgroundTransparency = variant.BackgroundTransparency,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(0.1, 0.8),
		AutomaticSize = if useImage then nil else Enum.AutomaticSize.Y,
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
			GameEvents.Bus:Emit(Events.UI.ButtonClicked, variantName)
			ButtonHelpers.animatePressSpring(uiScaleRef, variant, shouldAnimate)
			if props[React.Event.Activated] then
				props[React.Event.Activated](...)
			end
		end,
	}, children)
end

return IconButton
