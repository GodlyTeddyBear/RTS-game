--!strict
--[=[
	@class useTween
	React hook that returns a stable callback for triggering `TweenService`-based animations with automatic cancellation of overlapping tweens.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)
local useRef = React.useRef
local useCallback = React.useCallback

local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)

--[=[
	@interface TTweenConfig
	@within useTween
	.Duration number? -- Tween duration in seconds. Defaults to `AnimationTokens.Duration.Normal`.
	.EasingStyle Enum.EasingStyle? -- Easing style. Defaults to `Enum.EasingStyle.Quad`.
	.EasingDirection Enum.EasingDirection? -- Easing direction. Defaults to `Enum.EasingDirection.Out`.
	.RepeatCount number? -- Number of times to repeat. Defaults to `0`.
	.Reverses boolean? -- Whether the tween reverses. Defaults to `false`.
	.DelayTime number? -- Delay before starting in seconds. Defaults to `0`.
	.OnComplete (() -> ())? -- Callback fired when the tween completes.
]=]
export type TTweenConfig = {
	Duration: number?,
	EasingStyle: Enum.EasingStyle?,
	EasingDirection: Enum.EasingDirection?,
	RepeatCount: number?,
	Reverses: boolean?,
	DelayTime: number?,
	OnComplete: (() -> ())?,
}

--[[
    useTween - Animate properties with tweens

    Wraps TweenService to provide a React-friendly API for easing-based animations.
    Uses standard Roblox TweenService for predictable, easing-style motion.

    Usage:
        local tween = useTween()

        React.useEffect(function()
            tween(ref, { BackgroundTransparency = 0.5 }, {
                Duration = theme.Animation.Duration.Fast,
                EasingStyle = theme.Animation.Easing.Quad,
            })
        end, {})

    Arguments:
        instanceRef - React.Ref to the GuiObject to animate
        properties - Table of property names and target values
        config - Optional config table with Duration, EasingStyle, etc.

    Returns: callback function for triggering animations
]]
--[=[
	Return a stable callback that tweens a `GuiObject` ref's properties, cancelling any in-progress tween on the same instance.
	@within useTween
	@return (instanceRef: { current: GuiObject? }, properties: { [string]: any }, config: TTweenConfig?) -> () -- Tween trigger callback.
]=]
local function useTween()
	local activeTweensRef = useRef({} :: { [Instance]: Tween })

	return useCallback(function(
		instanceRef: { current: GuiObject? },
		properties: { [string]: any },
		config: TTweenConfig?
	)
		local instance = instanceRef.current
		if not instance then
			warn("[useTween] Instance ref is nil")
			return
		end

		-- Stop existing tween on this instance
		local existingTween = activeTweensRef.current[instance]
		if existingTween then
			existingTween:Cancel()
		end

		local duration = (config and config.Duration) or AnimationTokens.Duration.Normal
		local easingStyle = (config and config.EasingStyle) or Enum.EasingStyle.Quad
		local easingDirection = (config and config.EasingDirection) or Enum.EasingDirection.Out

		local tweenInfo = TweenInfo.new(
			duration,
			easingStyle,
			easingDirection,
			(config and config.RepeatCount) or 0,
			(config and config.Reverses) or false,
			(config and config.DelayTime) or 0
		)

		local tween = TweenService:Create(instance, tweenInfo, properties)
		activeTweensRef.current[instance] = tween

		tween.Completed:Connect(function()
			activeTweensRef.current[instance] = nil
			if config and config.OnComplete then
				config.OnComplete()
			end
		end)

		tween:Play()
	end, {})
end

return useTween
