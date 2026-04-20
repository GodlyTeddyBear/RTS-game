--!strict
--[=[
	@class useCountUp
	React hook that animates a number from its current value to a target with a count-up effect, returning a formatted string.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)
local useState = React.useState
local useRef = React.useRef
local useEffect = React.useEffect

local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
local useReducedMotion = require(script.Parent.useReducedMotion)
local EasingFunctions = require(script.Parent.EasingFunctions)

--[=[
	@interface TCountUpConfig
	@within useCountUp
	.Duration number? -- Animation duration in seconds. Defaults to `AnimationTokens.Duration.Normal`.
	.EasingStyle Enum.EasingStyle? -- Easing curve. Defaults to `Enum.EasingStyle.Quad`.
	.Prefix string? -- String prepended to the animated number.
	.Suffix string? -- String appended to the animated number.
	.OnComplete (() -> ())? -- Callback fired when the animation reaches the target value.
]=]
export type TCountUpConfig = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	Prefix: string?,
	Suffix: string?,
	OnComplete: (() -> ())?,
}

type TCancelHandle = { Cancel: () -> () }

--[[
    useCountUp - Animate number values with count-up effect

    Smoothly animates a number from its current value to a target value.
    Uses RunService.Heartbeat for smooth frame-by-frame interpolation.

    Usage:
        local displayValue = useCountUp(targetValue, {
            Duration = theme.Animation.Duration.Normal,
            Prefix = "Score: ",
            Suffix = " points",
        })

    Returns: Formatted string with animated number

    Example:
        useCountUp(100, { Duration = 0.5, Prefix = "Count: " })
        -- Returns: "Count: 42" (animates to 100 over 0.5 seconds)
]]
--[=[
	Animate a number toward `targetValue` and return it as a formatted string with optional prefix/suffix.
	@within useCountUp
	@param targetValue number -- The target number to animate toward.
	@param config TCountUpConfig? -- Optional duration, easing, prefix, suffix, and completion callback.
	@return string -- The currently displayed (animated) value as a formatted string.
]=]
local function useCountUp(targetValue: number, config: TCountUpConfig?)
	local prefersReducedMotion = useReducedMotion()

	local displayValue, setDisplayValue = useState(targetValue)
	local animationRef = useRef(nil :: TCancelHandle?)

	useEffect(function()
		if prefersReducedMotion then
			setDisplayValue(targetValue)
			return
		end

		local duration = (config and config.Duration) or AnimationTokens.Duration.Normal
		local easingStyle = (config and config.EasingStyle) or Enum.EasingStyle.Quad

		if animationRef.current then
			animationRef.current.Cancel()
		end

		local startValue = displayValue
		local startTime = os.clock()

		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - startTime
			local progress = math.min(elapsed / duration, 1)
			local easedProgress = EasingFunctions.applyEasing(progress, easingStyle)

			local animatedValue = startValue + (targetValue - startValue) * easedProgress
			setDisplayValue(math.floor(animatedValue + 0.5))

			if progress < 1 then
				return
			end

			connection:Disconnect()
			animationRef.current = nil
			setDisplayValue(targetValue)
			if config and config.OnComplete then
				config.OnComplete()
			end
		end)

		animationRef.current = {
			Cancel = function()
				if connection.Connected then
					connection:Disconnect()
				end
			end,
		}

		return function()
			if animationRef.current then
				animationRef.current.Cancel()
			end
		end
	end, { targetValue, prefersReducedMotion })

	local prefix = (config and config.Prefix) or ""
	local suffix = (config and config.Suffix) or ""
	return prefix .. tostring(displayValue) .. suffix
end

return useCountUp
