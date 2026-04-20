--!strict
--[=[
	@class FeatureCard
	Molecule displaying a feature icon, name, and availability status with hover effects.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

local e = React.createElement
local useRef = React.useRef
local useEffect = React.useEffect

local useSpring = require(script.Parent.Parent.Parent.Application.Hooks.useSpring)
local useHoverSpring = require(script.Parent.Parent.Parent.Application.Hooks.useHoverSpring)
local useReducedMotion = require(script.Parent.Parent.Parent.Application.Hooks.useReducedMotion)

local Text = require(script.Parent.Parent.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Config.ColorTokens)

export type TFeatureCardProps = {
	Title: string,
	Icon: string,
	Status: "available" | "coming-soon",
	OnPress: (() -> ())?,
	LayoutOrder: number?,
}

local function FeatureCard(props: TFeatureCardProps)
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()

	local cardRef = useRef(nil :: TextButton?)

	local isAvailable = props.Status == "available"

	local hover = useHoverSpring(cardRef, {
		HoverScale = 1.015,
		PressScale = 0.985,
		SpringPreset = "Gentle",
		Disabled = not isAvailable,
	})

	local bgColor = if hover.isHovered and isAvailable then Colors.Surface.Hover else Colors.Surface.Secondary
	local bgTransparency = if isAvailable then 0 else 0.5

	local shouldAnimate = not prefersReducedMotion

	useEffect(function()
		if not shouldAnimate or not cardRef.current or not isAvailable then
			return
		end

		spring(cardRef, {
			BackgroundColor3 = bgColor,
			BackgroundTransparency = bgTransparency,
		}, "Smooth")
	end, { hover.isHovered, shouldAnimate, isAvailable, bgColor, bgTransparency })

	local onPress = function()
		if isAvailable and props.OnPress then
			props.OnPress()
		end
	end

	return e("TextButton", {
		ref = cardRef,
		Size = UDim2.fromScale(0.3, 0.3),
		BackgroundColor3 = Colors.Surface.Secondary,
		BackgroundTransparency = bgTransparency,
		BorderSizePixel = 0,
		Text = "",
		Selectable = isAvailable,
		LayoutOrder = props.LayoutOrder,
		[React.Event.MouseEnter] = hover.onMouseEnter,
		[React.Event.MouseLeave] = hover.onMouseLeave,
		[React.Event.Activated] = hover.onActivated(onPress),
	}, {
		UICorner = e("UICorner", {
			CornerRadius = UDim.new(0.05, 0),
		}),

		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.05, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		UIPadding = e("UIPadding", {
			PaddingTop = UDim.new(0.075, 0),
			PaddingBottom = UDim.new(0.075, 0),
			PaddingLeft = UDim.new(0.075, 0),
			PaddingRight = UDim.new(0.075, 0),
		}),

		Icon = e(Text, {
			Text = props.Icon,
			TextSize = 48,
			LayoutOrder = 1,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),

		Title = e(Text, {
			Text = props.Title,
			Variant = "label",
			Size = UDim2.new(1, -24, 0, 0),
			LayoutOrder = 2,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = true,
		}),

		ComingSoonBadge = (props.Status == "coming-soon") and e(Text, {
			Text = "Coming Soon",
			Variant = "caption",
			LayoutOrder = 3,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}) or nil,
	})
end

return FeatureCard
