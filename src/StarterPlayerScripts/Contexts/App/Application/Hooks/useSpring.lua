--!strict
--[=[
	@class useSpring
	React hook that returns a stable callback for triggering spring-physics animations via the `spr` library.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useCallback = React.useCallback
local spr = require(ReplicatedStorage.Utilities.BitFrames.Dependencies.spr)

local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)

--[=[
	@interface TSpringConfig
	@within useSpring
	.DampingRatio number? -- Spring damping ratio. Defaults to `0.7`.
	.Frequency number? -- Spring frequency. Defaults to `2`.
	.OnComplete (() -> ())? -- Callback fired when the spring settles.
]=]
export type TSpringConfig = {
	DampingRatio: number?,
	Frequency: number?,
	OnComplete: (() -> ())?,
}

--[=[
	@type TSpringPreset "Gentle" | "Smooth" | "Default" | "Responsive" | "Bouncy" | "Wobbly"
	@within useSpring
]=]
export type TSpringPreset = "Gentle" | "Smooth" | "Default" | "Responsive" | "Bouncy" | "Wobbly"

--[[
    useSpring - Animate properties with spring physics

    Wraps the Spr library to provide a React-friendly API for spring-based animations.
    Uses physics-based motion for natural-feeling animations.

    Usage:
        local spring = useSpring()

        React.useEffect(function()
            spring(ref, { Size = UDim2.fromOffset(200, 100) }, "Responsive")
        end, {})

    Arguments:
        instanceRef - React.Ref to the GuiObject to animate
        properties - Table of property names and target values
        presetOrConfig - Spring preset name (string) or config table

    Returns: callback function for triggering animations
]]

local function _ResolveSpringParams(presetOrConfig: TSpringPreset | TSpringConfig?)
	local dampingRatio = 0.7
	local frequency = 2
	local onComplete: (() -> ())?

	if not presetOrConfig then
		return dampingRatio, frequency, onComplete
	end

	if typeof(presetOrConfig) == "string" then
		local preset = AnimationTokens.Spring[presetOrConfig]
		if preset then
			dampingRatio = preset.DampingRatio
			frequency = preset.Frequency
		else
			warn("[useSpring] Invalid spring preset:", presetOrConfig)
		end
	elseif typeof(presetOrConfig) == "table" then
		dampingRatio = presetOrConfig.DampingRatio or dampingRatio
		frequency = presetOrConfig.Frequency or frequency
		onComplete = presetOrConfig.OnComplete
	end

	return dampingRatio, frequency, onComplete
end

--[=[
	Return a stable callback that applies spring-physics animations to a `GuiObject` ref.
	@within useSpring
	@return (instanceRef: { current: GuiObject? }, properties: { [string]: any }, presetOrConfig: TSpringPreset | TSpringConfig?) -> () -- Animation trigger callback.
]=]
local function useSpring()
	return useCallback(function(
		instanceRef: { current: GuiObject? },
		properties: { [string]: any },
		presetOrConfig: TSpringPreset | TSpringConfig?
	)
		local instance = instanceRef.current
		if not instance then
			warn("[useSpring] Instance ref is nil")
			return
		end

		local dampingRatio, frequency, onComplete = _ResolveSpringParams(presetOrConfig)
		spr.target(instance, dampingRatio, frequency, properties)

		if onComplete then
			spr.completed(instance, onComplete)
		end
	end, {})
end

return useSpring
