--!strict
--[=[
	@class ButtonHelpers
	Shared variant table, spring helpers, `UIScale` management, and press animation logic used by `Button` and `IconButton`.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spr = require(ReplicatedStorage.Utilities.BitFrames.Dependencies.spr)
local Colors = require(script.Parent.Parent.Parent.Config.ColorTokens)
local Typography = require(script.Parent.Parent.Parent.Config.TypographyTokens)
local Border = require(script.Parent.Parent.Parent.Config.BorderTokens)

--[[
	ButtonHelpers - Shared internals for Button and IconButton atoms.

	Both atoms have identical variant tables, spring param lookup,
	UIScale management, and press animation logic. This module
	centralizes them so changes propagate to both.
]]

--[=[
	@type TButtonVariant "primary" | "secondary" | "ghost" | "danger"
	@within ButtonHelpers
]=]
export type TButtonVariant = "primary" | "secondary" | "ghost" | "danger"

--[=[
	@interface TVariantStyle
	@within ButtonHelpers
	.BackgroundColor3 Color3 -- Default background colour.
	.BackgroundHover Color3 -- Background colour when hovered.
	.TextColor3 Color3 -- Label text colour.
	.Font Enum.Font -- Label font.
	.TextSize number -- Label font size.
	.CornerRadius UDim -- Corner radius for the button's `UICorner`.
	.BackgroundTransparency number -- Default background transparency.
	.BackgroundHoverTransparency number -- Background transparency when hovered.
	.SpringPreset string -- Spring preset name used for the press animation.
	.ScalePressed number -- `UIScale.Scale` target during press animation.
]=]
export type TVariantStyle = {
	BackgroundColor3: Color3,
	BackgroundHover: Color3,
	TextColor3: Color3,
	Font: Enum.Font,
	TextSize: number,
	CornerRadius: UDim,
	BackgroundTransparency: number,
	BackgroundHoverTransparency: number,
	SpringPreset: string,
	ScalePressed: number,
}

local BUTTON_VARIANTS: { [string]: TVariantStyle } = {
	primary = {
		BackgroundColor3 = Colors.Surface.Tertiary,
		BackgroundHover = Colors.Surface.Hover,
		TextColor3 = Colors.Text.Primary,
		Font = Typography.Font.Heading,
		TextSize = Typography.FontSize.Body,
		CornerRadius = Border.Radius.MD,
		BackgroundTransparency = 0,
		BackgroundHoverTransparency = 0,
		SpringPreset = "Responsive",
		ScalePressed = 0.95,
	},
	secondary = {
		BackgroundColor3 = Colors.Surface.Secondary,
		BackgroundHover = Colors.Surface.Tertiary,
		TextColor3 = Colors.Text.Secondary,
		Font = Typography.Font.Heading,
		TextSize = Typography.FontSize.Body,
		CornerRadius = Border.Radius.MD,
		BackgroundTransparency = 0,
		BackgroundHoverTransparency = 0,
		SpringPreset = "Smooth",
		ScalePressed = 0.96,
	},
	ghost = {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundHover = Colors.Surface.Tertiary,
		TextColor3 = Colors.Text.Primary,
		Font = Typography.Font.Heading,
		TextSize = Typography.FontSize.Body,
		CornerRadius = Border.Radius.MD,
		BackgroundTransparency = 1,
		BackgroundHoverTransparency = 0,
		SpringPreset = "Gentle",
		ScalePressed = 0.97,
	},
	danger = {
		BackgroundColor3 = Colors.Semantic.Error,
		BackgroundHover = Color3.fromRGB(200, 80, 80),
		TextColor3 = Colors.Text.OnDark,
		Font = Typography.Font.Heading,
		TextSize = Typography.FontSize.Body,
		CornerRadius = Border.Radius.MD,
		BackgroundTransparency = 0,
		BackgroundHoverTransparency = 0,
		SpringPreset = "Bouncy",
		ScalePressed = 0.94,
	},
}

local function getSpringParams(presetName: string): (number, number)
	local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
	local preset = AnimationTokens.Spring[presetName]
	if preset then
		return preset.DampingRatio, preset.Frequency
	end
	return 0.6, 2.5 -- Default if preset not found
end

--[=[
	Return the existing `UIScale` child of `instance`, or create and parent one with `Scale = 1`.
	@within ButtonHelpers
	@param instance GuiObject -- The button instance to manage.
	@return UIScale? -- The `UIScale` instance.
]=]
local function ensureUIScale(instance: GuiObject): UIScale?
	local existing = instance:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	-- Create a new UIScale for press animation
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ButtonPressScale"
	uiScale.Scale = 1
	uiScale.Parent = instance
	return uiScale
end

--[=[
	Animate a button's `UIScale` to `variant.ScalePressed` and spring back to `1` on completion.
	@within ButtonHelpers
	@param uiScaleRef { current: UIScale? } -- Ref to the `UIScale` instance.
	@param variant TVariantStyle -- The button variant that provides `ScalePressed` and `SpringPreset`.
	@param shouldAnimate boolean -- When `false`, the function is a no-op.
]=]
local function animatePressSpring(
	uiScaleRef: { current: UIScale? },
	variant: TVariantStyle,
	shouldAnimate: boolean
)
	-- Skip if animations disabled or UIScale missing
	if not shouldAnimate or not uiScaleRef.current then
		return
	end
	local dampingRatio, frequency = getSpringParams(variant.SpringPreset)

	-- Spring to pressed scale
	spr.target(uiScaleRef.current, dampingRatio, frequency, {
		Scale = variant.ScalePressed,
	})

	-- Spring back to normal scale when press animation completes
	spr.completed(uiScaleRef.current, function()
		if uiScaleRef.current then
			spr.target(uiScaleRef.current, dampingRatio, frequency, {
				Scale = 1,
			})
		end
	end)
end

return {
	BUTTON_VARIANTS = BUTTON_VARIANTS,
	getSpringParams = getSpringParams,
	ensureUIScale = ensureUIScale,
	animatePressSpring = animatePressSpring,
}
