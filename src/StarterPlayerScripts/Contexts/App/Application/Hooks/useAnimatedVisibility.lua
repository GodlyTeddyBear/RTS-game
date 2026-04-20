--!strict
--[=[
	@class useAnimatedVisibility
	React hook that animates elements entering and exiting the view, keeping them rendered during the exit animation.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local useState = React.useState
local useRef = React.useRef
local useEffect = React.useEffect

local spr = require(ReplicatedStorage.Utilities.BitFrames.Dependencies.spr)
local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
local useReducedMotion = require(script.Parent.useReducedMotion)

--[=[
	@type TVisibilityMode "slideRight" | "slideUp" | "fadeScale" | "fade"
	@within useAnimatedVisibility
]=]
export type TVisibilityMode = "slideRight" | "slideUp" | "fadeScale" | "fade"

--[=[
	@interface TAnimatedVisibilityConfig
	@within useAnimatedVisibility
	.Mode TVisibilityMode? -- Animation mode. Defaults to `"slideRight"`.
	.SpringPreset string? -- Spring preset name from `AnimationTokens.Spring`. Defaults to `"Smooth"`.
]=]
export type TAnimatedVisibilityConfig = {
	Mode: TVisibilityMode?,
	SpringPreset: string?,
}

--[=[
	@interface TAnimatedVisibilityResult
	@within useAnimatedVisibility
	.shouldRender boolean -- Whether the element should remain mounted (false only after exit animation completes).
	.containerRef { current: Frame? } -- Ref to assign to the animated container frame.
]=]
export type TAnimatedVisibilityResult = {
	shouldRender: boolean,
	containerRef: { current: Frame? },
}

--[[
    useAnimatedVisibility - Animate elements entering and exiting the view.

    Handles mount/unmount transitions for detail panels, dropdown menus, modals, etc.
    The element stays rendered during exit animation, then shouldRender becomes false.

    Usage:
        local visibility = useAnimatedVisibility(isItemSelected, {
            Mode = "slideRight",
            SpringPreset = "Smooth",
        })

        if visibility.shouldRender then
            return e("Frame", {
                ref = visibility.containerRef,
                ...
            })
        end

    Modes:
        slideRight - Enter from right, exit to right + fade. For detail panels.
        slideUp    - Enter from below, exit downward + fade. For dropdowns.
        fadeScale  - Scale 0.9→1.0 + fade. For modals/popups.
        fade       - Transparency 0↔1. For tab content.
]]

-- Look up spring parameters from AnimationTokens or use defaults
local function _GetSpringParams(presetName: string): (number, number)
	local preset = AnimationTokens.Spring[presetName]
	if preset then
		return preset.DampingRatio, preset.Frequency
	end
	return 0.8, 1.5 -- Smooth fallback if preset not found
end

-- Collect all GuiObject children of the container (used for animating children during enter/exit)
local function _GetAnimatableChildren(container: Frame): { GuiObject }
	local children: { GuiObject } = {}
	for _, child in container:GetChildren() do
		if child:IsA("GuiObject") then
			table.insert(children, child)
		end
	end
	return children
end

-- Get the animation offset for the given mode (distance to slide or fade)
local function _GetModeOffsetUDim2(mode: TVisibilityMode): UDim2
	if mode == "slideRight" then
		return UDim2.fromScale(0.05, 0)
	elseif mode == "slideUp" then
		return UDim2.fromScale(0, 0.05)
	end
	return UDim2.fromScale(0, 0)
end

local function _SnapToHiddenState(
	container: Frame,
	animatableChildren: { GuiObject },
	mode: TVisibilityMode
)
	if mode == "slideRight" or mode == "slideUp" then
		container.Position = container.Position + _GetModeOffsetUDim2(mode)
		container.BackgroundTransparency = 1
		for _, child in animatableChildren do
			child.BackgroundTransparency = 1
		end
	elseif mode == "fadeScale" then
		container.Size = UDim2.new(
			container.Size.X.Scale * 0.9,
			container.Size.X.Offset,
			container.Size.Y.Scale * 0.9,
			container.Size.Y.Offset
		)
		container.BackgroundTransparency = 1
	elseif mode == "fade" then
		container.BackgroundTransparency = 1
	end
end

local function _BuildEnterTargetProps(
	container: Frame,
	mode: TVisibilityMode
): { [string]: any }
	local enterProps: { [string]: any } = {}

	if mode == "slideRight" then
		enterProps.Position = container.Position - UDim2.fromScale(0.05, 0)
		enterProps.BackgroundTransparency = 0
	elseif mode == "slideUp" then
		enterProps.Position = container.Position - UDim2.fromScale(0, 0.05)
		enterProps.BackgroundTransparency = 0
	elseif mode == "fadeScale" then
		enterProps.Size = UDim2.new(
			container.Size.X.Scale / 0.9,
			container.Size.X.Offset,
			container.Size.Y.Scale / 0.9,
			container.Size.Y.Offset
		)
		enterProps.BackgroundTransparency = 0
	elseif mode == "fade" then
		enterProps.BackgroundTransparency = 0
	end

	return enterProps
end

local function _BuildExitTargetProps(
	container: Frame,
	mode: TVisibilityMode
): { [string]: any }
	local exitProps: { [string]: any } = {}

	if mode == "slideRight" then
		exitProps.Position = container.Position + UDim2.fromScale(0.05, 0)
		exitProps.BackgroundTransparency = 1
	elseif mode == "slideUp" then
		exitProps.Position = container.Position + UDim2.fromScale(0, 0.05)
		exitProps.BackgroundTransparency = 1
	elseif mode == "fadeScale" then
		exitProps.Size = UDim2.new(
			container.Size.X.Scale * 0.9,
			container.Size.X.Offset,
			container.Size.Y.Scale * 0.9,
			container.Size.Y.Offset
		)
		exitProps.BackgroundTransparency = 1
	elseif mode == "fade" then
		exitProps.BackgroundTransparency = 1
	end

	return exitProps
end

-- Play entrance animation (snap to hidden state, then spring to visible)
local function _AnimateEnter(
	containerRef: { current: Frame? },
	mode: TVisibilityMode,
	dampingRatio: number,
	frequency: number,
	setShouldRender: (value: boolean) -> (),
	isAnimatingRef: { current: boolean }
)
	-- Mark as rendering and animating
	setShouldRender(true)
	isAnimatingRef.current = true

	task.defer(function()
		local container = containerRef.current
		if not container then
			isAnimatingRef.current = false
			return
		end

		-- Get children to animate along with container
		local animatableChildren = _GetAnimatableChildren(container)

		-- Snap container and children to starting positions (off-screen or hidden)
		_SnapToHiddenState(container, animatableChildren, mode)

		-- Spring the container from hidden state to visible position
		local enterProps = _BuildEnterTargetProps(container, mode)
		spr.target(container, dampingRatio, frequency, enterProps)

		-- For slide modes, also animate children from transparent to opaque
		if mode == "slideRight" or mode == "slideUp" then
			for _, child in animatableChildren do
				spr.target(child, dampingRatio, frequency, { BackgroundTransparency = 0 })
			end
		end

		-- Clear animating flag when spring settles
		spr.completed(container, function()
			isAnimatingRef.current = false
		end)
	end)
end

-- Play exit animation (spring to hidden state, then unmount)
local function _AnimateExit(
	containerRef: { current: Frame? },
	mode: TVisibilityMode,
	dampingRatio: number,
	frequency: number,
	setShouldRender: (value: boolean) -> (),
	isAnimatingRef: { current: boolean }
)
	isAnimatingRef.current = true

	local container = containerRef.current
	if not container then
		-- No container; can't animate, so just unmount immediately
		setShouldRender(false)
		isAnimatingRef.current = false
		return
	end

	-- Get children to animate along with container
	local animatableChildren = _GetAnimatableChildren(container)

	-- For slide modes, animate children to transparent before sliding out
	if mode == "slideRight" or mode == "slideUp" then
		for _, child in animatableChildren do
			spr.target(child, dampingRatio, frequency, { BackgroundTransparency = 1 })
		end
	end

	-- Spring the container from visible to hidden position
	local exitProps = _BuildExitTargetProps(container, mode)
	spr.target(container, dampingRatio, frequency, exitProps)

	-- Unmount when exit animation finishes
	spr.completed(container, function()
		isAnimatingRef.current = false
		setShouldRender(false)
	end)
end

--[=[
	Animate an element's enter and exit transitions, deferring unmount until the exit animation completes.
	@within useAnimatedVisibility
	@param isVisible boolean -- Whether the element should be visible.
	@param config TAnimatedVisibilityConfig? -- Optional mode and spring preset overrides.
	@return TAnimatedVisibilityResult -- Render flag and container ref to attach to the animated frame.
]=]
local function useAnimatedVisibility(
	isVisible: boolean,
	config: TAnimatedVisibilityConfig?
): TAnimatedVisibilityResult
	local prefersReducedMotion = useReducedMotion()
	local mode: TVisibilityMode = (config and config.Mode) or "slideRight"
	local springPreset = (config and config.SpringPreset) or "Smooth"

	local shouldRender, setShouldRender = useState(isVisible)
	local containerRef = useRef(nil :: Frame?)
	local isAnimatingRef = useRef(false)
	local prevVisibleRef = useRef(isVisible)

	-- Detect visibility changes and trigger appropriate animation
	useEffect(function()
		-- Skip if visibility state hasn't changed
		if prevVisibleRef.current == isVisible then
			return
		end
		prevVisibleRef.current = isVisible

		-- Respect reduced motion: show/hide instantly without animation
		if prefersReducedMotion then
			setShouldRender(isVisible)
			return
		end

		-- Get spring params and trigger the appropriate animation
		local dampingRatio, frequency = _GetSpringParams(springPreset)

		if isVisible then
			_AnimateEnter(containerRef, mode, dampingRatio, frequency, setShouldRender, isAnimatingRef)
		else
			_AnimateExit(containerRef, mode, dampingRatio, frequency, setShouldRender, isAnimatingRef)
		end
	end, { isVisible, prefersReducedMotion } :: { any })

	return {
		shouldRender = shouldRender,
		containerRef = containerRef,
	}
end

return useAnimatedVisibility
