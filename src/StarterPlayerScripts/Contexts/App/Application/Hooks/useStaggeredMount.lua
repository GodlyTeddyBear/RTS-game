--!strict
--[=[
	@class useStaggeredMount
	React hook that delays visibility of list or grid items by their index, creating a cascading entrance effect.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useState = React.useState
local useEffect = React.useEffect

local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
local useReducedMotion = require(script.Parent.useReducedMotion)

--[=[
	@interface TStaggerConfig
	@within useStaggeredMount
	.Delay number? -- Seconds per index step. Defaults to `AnimationTokens.Stagger.Grid.Delay`.
	.MaxDelay number? -- Maximum total delay cap. Defaults to `AnimationTokens.Stagger.Grid.MaxDelay`.
]=]
export type TStaggerConfig = {
	Delay: number?,
	MaxDelay: number?,
}

--[[
    useStaggeredMount - Stagger the appearance of list/grid items.

    Each item at index i waits min(i * Delay, MaxDelay) seconds before
    becoming visible, creating a cascading entrance effect.

    Usage:
        local function GridItem(props)
            local isVisible = useStaggeredMount(props.Index, {
                Delay = 0.025,
                MaxDelay = 0.3,
            })

            return e("Frame", {
                BackgroundTransparency = if isVisible then 0 else 1,
                ...
            })
        end

    Returns: boolean (true when the item should be visible)
]]
--[=[
	Return `true` after a staggered delay of `min(index * Delay, MaxDelay)` seconds, enabling cascading entrance effects.
	@within useStaggeredMount
	@param index number -- Zero-based position of the item in the list or grid.
	@param config TStaggerConfig? -- Optional delay step and max delay overrides.
	@return boolean -- `true` once the item's delay has elapsed.
]=]
local function useStaggeredMount(index: number, config: TStaggerConfig?): boolean
	local prefersReducedMotion = useReducedMotion()

	local isVisible, setIsVisible = useState(false)

	local delay = (config and config.Delay) or AnimationTokens.Stagger.Grid.Delay
	local maxDelay = (config and config.MaxDelay) or AnimationTokens.Stagger.Grid.MaxDelay

	useEffect(function()
		if prefersReducedMotion then
			setIsVisible(true)
			return
		end

		local itemDelay = math.min(index * delay, maxDelay)

		local thread = task.delay(itemDelay, function()
			setIsVisible(true)
		end)

		return function()
			task.cancel(thread)
			setIsVisible(false)
		end
	end, { index, prefersReducedMotion } :: { any })

	return isVisible
end

return useStaggeredMount
