--!strict
--[=[
	@class useHoverSpring
	React hook that drives hover-scale and press-scale spring animations on interactive elements via a managed `UIScale`.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useRef = React.useRef
local useCallback = React.useCallback
local useEffect = React.useEffect
local useState = React.useState

local spr = require(ReplicatedStorage.Utilities.BitFrames.Dependencies.spr)
local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
local useReducedMotion = require(script.Parent.useReducedMotion)

--[=[
	@interface THoverSpringConfig
	@within useHoverSpring
	.HoverScale number? -- UIScale target on hover. Defaults to `1.03`.
	.PressScale number? -- UIScale target on press. Defaults to `0.95`.
	.SpringPreset string? -- Spring preset name from `AnimationTokens.Spring`. Defaults to `"Responsive"`.
	.Disabled boolean? -- When `true`, all animations are skipped.
]=]
export type THoverSpringConfig = {
	HoverScale: number?,
	PressScale: number?,
	SpringPreset: string?,
	Disabled: boolean?,
}

--[=[
	@interface THoverSpringResult
	@within useHoverSpring
	.isHovered boolean -- Whether the element is currently hovered.
	.onMouseEnter () -> () -- Pass to `[React.Event.MouseEnter]`.
	.onMouseLeave () -> () -- Pass to `[React.Event.MouseLeave]`.
	.onActivated (originalCallback: ((...any) -> ())?) -> (...any) -> () -- Wraps a callback with press animation; pass to `[React.Event.Activated]`.
]=]
export type THoverSpringResult = {
	isHovered: boolean,
	onMouseEnter: () -> (),
	onMouseLeave: () -> (),
	onActivated: (originalCallback: ((...any) -> ())?) -> (...any) -> (),
}

--[[
    useHoverSpring - Reusable hover+press spring animation for interactive elements.

    Uses UIScale to animate scale independently of the element's Size property.
    On hover: springs to HoverScale. On press: springs to PressScale then back to 1.0.

    Usage:
        local buttonRef = useRef(nil)
        local hover = useHoverSpring(buttonRef, {
            HoverScale = 1.04,
            PressScale = 0.96,
            SpringPreset = "Responsive",
        })

        return e("TextButton", {
            ref = buttonRef,
            [React.Event.MouseEnter] = hover.onMouseEnter,
            [React.Event.MouseLeave] = hover.onMouseLeave,
            [React.Event.Activated] = hover.onActivated(myCallback),
        })
]]

-- Resolve spring params from preset or use responsive fallback
local function _GetSpringParams(presetName: string): (number, number)
	local preset = AnimationTokens.Spring[presetName]
	if preset then
		return preset.DampingRatio, preset.Frequency
	end
	return 0.6, 2.5 -- Responsive fallback if preset not found
end

-- Ensure a UIScale child exists for hover/press animations
local function _EnsureUIScale(instance: GuiObject): UIScale?
	local existing = instance:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	-- Create new UIScale for hover and press animations
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "HoverSpringScale"
	uiScale.Scale = 1
	uiScale.Parent = instance
	return uiScale
end

--[=[
	Attach hover and press spring animations to an interactive element via a managed `UIScale`.
	@within useHoverSpring
	@param instanceRef { current: GuiObject? } -- Ref to the `GuiObject` to animate.
	@param config THoverSpringConfig? -- Optional scale targets, spring preset, and disabled flag.
	@return THoverSpringResult -- Event handlers and hover state to spread onto the element.
]=]
local function useHoverSpring(
	instanceRef: { current: GuiObject? },
	config: THoverSpringConfig?
): THoverSpringResult
	local prefersReducedMotion = useReducedMotion()

	local hoverScale = (config and config.HoverScale) or 1.03
	local pressScale = (config and config.PressScale) or 0.95
	local springPreset = (config and config.SpringPreset) or "Responsive"
	local disabled = (config and config.Disabled) or false

	local isHovered, setIsHovered = useState(false)
	local uiScaleRef = useRef(nil :: UIScale?)

	local shouldAnimate = not prefersReducedMotion and not disabled

	-- Create UIScale child for animations
	useEffect(function()
		if not instanceRef.current then
			return
		end
		uiScaleRef.current = _EnsureUIScale(instanceRef.current)

		-- Cleanup: destroy UIScale on unmount
		return function()
			if uiScaleRef.current and uiScaleRef.current.Parent then
				uiScaleRef.current:Destroy()
				uiScaleRef.current = nil
			end
		end
	end, {})

	-- Spring to hover scale or back to 1 when hover state changes
	useEffect(function()
		if not shouldAnimate or not uiScaleRef.current then
			return
		end
		local dampingRatio, frequency = _GetSpringParams(springPreset)
		-- Target scale depends on hover state
		local targetScale = if isHovered then hoverScale else 1
		spr.target(uiScaleRef.current, dampingRatio, frequency, {
			Scale = targetScale,
		})
	end, { isHovered, shouldAnimate } :: { any })

	-- Mouse enter handler
	local onMouseEnter = useCallback(function()
		setIsHovered(true)
	end, {})

	-- Mouse leave handler
	local onMouseLeave = useCallback(function()
		setIsHovered(false)
	end, {})

	-- Press handler: scale down then back up, then call original callback
	local onActivated = useCallback(function(originalCallback: ((...any) -> ())?)
		return function(...)
			-- Play press animation if enabled
			if shouldAnimate and uiScaleRef.current then
				local dampingRatio, frequency = _GetSpringParams(springPreset)
				-- Spring to pressed scale
				spr.target(uiScaleRef.current, dampingRatio, frequency, {
					Scale = pressScale,
				})
				-- Spring back to normal scale when press finishes
				spr.completed(uiScaleRef.current, function()
					if uiScaleRef.current then
						spr.target(uiScaleRef.current, dampingRatio, frequency, {
							Scale = 1,
						})
					end
				end)
			end

			-- Invoke the original callback
			if originalCallback then
				originalCallback(...)
			end
		end
	end, { shouldAnimate } :: { any })

	return {
		isHovered = isHovered,
		onMouseEnter = onMouseEnter,
		onMouseLeave = onMouseLeave,
		onActivated = onActivated,
	}
end

return useHoverSpring
