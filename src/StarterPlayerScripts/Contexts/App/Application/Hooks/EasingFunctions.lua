--!strict
--[=[
	@class EasingFunctions
	Shared easing function lookup table used by animation hooks to apply easing curves to a normalized progress value.
	@client
]=]

--[[
	EasingFunctions - Shared easing function lookup table for animation hooks.

	Used by useCountUp and useAnimatedValue to apply easing curves to
	a normalized progress value in [0, 1].
]]

local EasingFunctions: { [Enum.EasingStyle]: (progress: number) -> number } = {
	[Enum.EasingStyle.Linear] = function(t: number): number
		return t
	end,
	[Enum.EasingStyle.Quad] = function(t: number): number
		return t * t
	end,
	[Enum.EasingStyle.Cubic] = function(t: number): number
		return t * t * t
	end,
	[Enum.EasingStyle.Sine] = function(t: number): number
		return 1 - math.cos(t * math.pi / 2)
	end,
	[Enum.EasingStyle.Exponential] = function(t: number): number
		return if t == 0 then 0 else math.pow(2, 10 * (t - 1))
	end,
}

--[=[
	Apply an easing curve to a normalized progress value.
	@within EasingFunctions
	@param progress number -- Normalized progress in `[0, 1]`.
	@param easingStyle Enum.EasingStyle -- The easing style to apply.
	@return number -- The eased progress value.
]=]
local function applyEasing(progress: number, easingStyle: Enum.EasingStyle): number
	local easingFn = EasingFunctions[easingStyle]
	return easingFn and easingFn(progress) or progress
end

return {
	applyEasing = applyEasing,
}
