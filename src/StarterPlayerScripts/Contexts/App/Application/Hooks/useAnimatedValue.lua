--!strict
--[=[
	@class useAnimatedValue
	React hook that smoothly interpolates any numeric value using `RunService.Heartbeat`.
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
	@interface TAnimatedValueConfig
	@within useAnimatedValue
	.Duration number? -- Animation duration in seconds. Defaults to `AnimationTokens.Duration.Normal`.
	.EasingStyle Enum.EasingStyle? -- Easing curve. Defaults to `Enum.EasingStyle.Quad`.
]=]
export type TAnimatedValueConfig = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
}

type TCancelHandle = { Cancel: () -> () }

--[[
    useAnimatedValue - Smoothly interpolate any numeric value.

    More general than useCountUp — works with any float (0-1 for progress bars, etc.)
    and returns a raw number instead of a formatted string.

    Usage:
        local animatedProgress = useAnimatedValue(targetProgress, {
            Duration = 0.4,
            EasingStyle = Enum.EasingStyle.Quad,
        })
        -- animatedProgress smoothly transitions from current to target

    Returns: current interpolated number value
]]
--[=[
	Animate a numeric value from its current interpolated state to a new target.
	@within useAnimatedValue
	@param targetValue number -- The target number to animate toward.
	@param config TAnimatedValueConfig? -- Optional duration and easing overrides.
	@return number -- The current interpolated value.
]=]
local function useAnimatedValue(targetValue: number, config: TAnimatedValueConfig?): number
	local prefersReducedMotion = useReducedMotion()

	local currentValue, setCurrentValue = useState(targetValue)
	local animationRef = useRef(nil :: TCancelHandle?)

	useEffect(function()
		if prefersReducedMotion then
			setCurrentValue(targetValue)
			return
		end

		local duration = (config and config.Duration) or AnimationTokens.Duration.Normal
		local easingStyle = (config and config.EasingStyle) or Enum.EasingStyle.Quad

		if animationRef.current then
			animationRef.current.Cancel()
		end

		local startValue = currentValue
		local startTime = os.clock()

		local connection: RBXScriptConnection
		connection = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - startTime
			local progress = math.min(elapsed / duration, 1)
			local easedProgress = EasingFunctions.applyEasing(progress, easingStyle)

			local currentAnimatedValue = startValue + (targetValue - startValue) * easedProgress
			setCurrentValue(currentAnimatedValue)

			if progress >= 1 then
				connection:Disconnect()
				animationRef.current = nil
				setCurrentValue(targetValue)
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
	end, { targetValue, prefersReducedMotion } :: { any })

	return currentValue
end

return useAnimatedValue
