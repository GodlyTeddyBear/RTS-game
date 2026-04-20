--!strict
--[=[
	@class useScreenTransition
	React hook that drives phased enter/exit animations for screens, communicating with `AnimatedRouter` via `TransitionContext`.
	@client
]=]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Promise = require(ReplicatedStorage.Packages.Promise)

local useEffect = React.useEffect
local useRef = React.useRef
local useState = React.useState
local useContext = React.useContext
local useMemo = React.useMemo

local spr = require(ReplicatedStorage.Utilities.BitFrames.Dependencies.spr)
local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
local TransitionPresets = require(script.Parent.Parent.Parent.Config.TransitionPresets)
local TransitionContext = require(script.Parent.Parent.Parent.Presentation.TransitionContext)
local useReducedMotion = require(script.Parent.useReducedMotion)

--[[
	useScreenTransition - Unified screen transition animation hook.

	Communicates with AnimatedRouter via TransitionContext (React context).
	Supports phased enter and exit animations with sequential Promise chains
	and optional parallel phase groups.

	The hook:
	1. Looks up a preset config by name from TransitionPresets
	2. On mount: defers one frame, finds elements by name, snaps to origins,
	   reveals container, runs enter phases sequentially
	3. Registers an exit handler via context so the router can trigger exit
	4. On exit: runs exit phases (sequentially or grouped), calls onComplete

	Usage:
		local anim = useScreenTransition("Standard")

		return React.createElement("Frame", {
			ref = anim.containerRef,
			Visible = false,
			Size = UDim2.fromScale(1, 1),
		}, {
			Header = e(MyHeader),
			Content = e(MyContent),
			Footer = e(MyFooter),
		})

	Returns:
		containerRef: Ref to assign to the screen's root Frame
		isEntering: true while enter phases are running
		isExiting: true while exit phases are running
]]

-- Types

type TDirection = TransitionPresets.TDirection
type TElementAnimation = TransitionPresets.TElementAnimation
type TPhase = TransitionPresets.TPhase
type TPresetConfig = TransitionPresets.TPresetConfig

--[=[
	@interface TScreenTransitionResult
	@within useScreenTransition
	.containerRef { current: Frame? } -- Ref to assign to the screen's root `Frame` (must be `Visible = false` initially).
	.isEntering boolean -- `true` while enter phases are running.
	.isExiting boolean -- `true` while exit phases are running.
]=]
export type TScreenTransitionResult = {
	containerRef: { current: Frame? },
	isEntering: boolean,
	isExiting: boolean,
}

-- Constants
local DEFAULTS = AnimationTokens.ScreenEntrance
local TRANSITION_SPRING = AnimationTokens.Transition.Slide.Spring
local PHASE_TIMEOUT = 3.0

-- Low-level helpers

local function _DirectionToOffset(direction: TDirection, magnitude: number): UDim2
	if direction == "fromTop" then
		return UDim2.fromScale(0, -magnitude)
	elseif direction == "fromBottom" then
		return UDim2.fromScale(0, magnitude)
	elseif direction == "fromLeft" then
		return UDim2.fromScale(-magnitude, 0)
	elseif direction == "fromRight" then
		return UDim2.fromScale(magnitude, 0)
	end
	return UDim2.fromScale(0, 0)
end

local function _ResolveSpring(elementSpring: string?, phaseSpring: string?): (number, number)
	local presetName = elementSpring or phaseSpring
	if presetName then
		local preset = AnimationTokens.Spring[presetName]
		if preset then
			return preset.DampingRatio, preset.Frequency
		end
	end
	return TRANSITION_SPRING.DampingRatio, TRANSITION_SPRING.Frequency
end

local function _GetOrCreateUIScale(instance: GuiObject, initialScale: number): UIScale
	local existing = instance:FindFirstChild("_TransitionScale")
	if existing and existing:IsA("UIScale") then
		existing.Scale = initialScale
		return existing
	end
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "_TransitionScale"
	uiScale.Scale = initialScale
	uiScale.Parent = instance
	return uiScale
end

local function _ResolveCompletionTarget(
	child: GuiObject,
	elemDirection: TDirection,
	scale: boolean
): Instance
	if scale and elemDirection == "none" then
		local uiScaleInst = child:FindFirstChild("_TransitionScale")
		if uiScaleInst then
			return uiScaleInst
		end
	end
	return child
end

-- Locate animation targets by name (direct children of container only)
local function _FindElements(
	container: Frame,
	elementNames: { string }
): { [string]: GuiObject }
	local found: { [string]: GuiObject } = {}
	for _, name in elementNames do
		local child = container:FindFirstChild(name)
		if child and child:IsA("GuiObject") then
			found[name] = child
		end
	end
	return found
end

-- Snap elements to their starting positions for entrance animations (hidden state)
local function _SnapToOrigins(
	phases: { TPhase },
	elements: { [string]: GuiObject }
): ({ [string]: UDim2 }, { UIScale })
	local originalPositions: { [string]: UDim2 } = {}
	local createdScales: { UIScale } = {}
	local snapped: { [string]: boolean } = {}

	-- Iterate all phases and snap elements to offsets (only process each element once)
	for _, phase in phases do
		for name, animConfig in phase.Elements do
			if snapped[name] then
				continue
			end

			local child = elements[name]
			if not child then
				continue
			end

			local direction: TDirection = animConfig.Direction or "fromRight"
			local offset = animConfig.Offset or DEFAULTS.DefaultOffset
			local scale = animConfig.Scale or false
			local scaleFrom = animConfig.ScaleFrom or DEFAULTS.DefaultScaleFrom

			-- Offset position to the "from" state (where the animation starts)
			if direction ~= "none" then
				originalPositions[name] = child.Position
				child.Position = child.Position + _DirectionToOffset(direction, offset)
			end

			-- Initialize UIScale for scale animations
			if scale then
				local uiScale = _GetOrCreateUIScale(child, scaleFrom)
				table.insert(createdScales, uiScale)
			end

			snapped[name] = true
		end
	end

	return originalPositions, createdScales
end

-- Run a single animation phase (all elements in the phase spring concurrently)
local function _ExecutePhase(
	phase: TPhase,
	elements: { [string]: GuiObject },
	originalPositions: { [string]: UDim2 },
	direction: "enter" | "exit",
	createdScales: { UIScale }
): any
	local elementPromises = {}

	-- Animate each element in the phase (concurrently, with optional stagger or delay)
	for name, animConfig in phase.Elements do
		local child = elements[name]
		if not child or not child.Parent then
			continue
		end

		local elemDirection: TDirection = animConfig.Direction or "fromRight"
		local offset = animConfig.Offset or DEFAULTS.DefaultOffset
		local scale = animConfig.Scale or false
		local scaleFrom = animConfig.ScaleFrom or DEFAULTS.DefaultScaleFrom
		local damping, freq = _ResolveSpring(animConfig.Spring, phase.DefaultSpring)

		-- Compute animation delay (stagger by index OR explicit delay)
		local delay: number = 0
		if animConfig.Delay then
			delay = animConfig.Delay
		elseif animConfig.StaggerIndex then
			local staggerDelay = phase.StaggerDelay or DEFAULTS.DefaultStaggerDelay
			delay = animConfig.StaggerIndex * staggerDelay
		end

		local elementPromise = (if delay > 0 then Promise.delay(delay) else Promise.resolve())
			:andThen(function()
				-- Guard: element may have been unmounted during delay
				if not child.Parent then
					return
				end

				return Promise.new(function(resolve)
					if direction == "enter" then
						-- Animate back to original position and scale 1
						local targetPos = originalPositions[name]
						if elemDirection ~= "none" and targetPos then
							spr.target(child, damping, freq, { Position = targetPos })
						end

						if scale then
							local uiScaleInst = child:FindFirstChild("_TransitionScale")
							if uiScaleInst and uiScaleInst:IsA("UIScale") then
								spr.target(uiScaleInst, damping, freq, { Scale = 1 })
							end
						end

						spr.completed(_ResolveCompletionTarget(child, elemDirection, scale), resolve)

					elseif direction == "exit" then
						-- Animate to offset and scale back to scaleFrom
						if elemDirection ~= "none" then
							spr.target(child, damping, freq, {
								Position = child.Position + _DirectionToOffset(elemDirection, offset),
							})
						end

						if scale then
							local uiScaleInst = _GetOrCreateUIScale(child, 1)
							table.insert(createdScales, uiScaleInst)
							spr.target(uiScaleInst, damping, freq, { Scale = scaleFrom })
						end

						spr.completed(_ResolveCompletionTarget(child, elemDirection, scale), resolve)
					end
				end)
			end)

		table.insert(elementPromises, elementPromise)
	end

	-- Return immediately if no elements to animate
	if #elementPromises == 0 then
		return Promise.resolve()
	end

	-- Race all element animations against timeout to prevent hanging
	return Promise.race({
		Promise.all(elementPromises),
		Promise.delay(PHASE_TIMEOUT):andThen(function()
			warn("[useScreenTransition] Phase timeout reached — forcing completion")
		end),
	})
end

-- Execute phases with ordered groups.
-- Default behavior remains sequential.
-- If adjacent phases share the same ParallelGroup, that group runs concurrently.
local function _ExecutePhases(
	phases: { TPhase },
	elements: { [string]: GuiObject },
	originalPositions: { [string]: UDim2 },
	direction: "enter" | "exit",
	createdScales: { UIScale }
): any
	local chain = Promise.resolve()
	local index = 1

	while index <= #phases do
		local currentPhase = phases[index]
		local parallelGroup = currentPhase.ParallelGroup

		-- No group => keep the original sequential behavior
		if parallelGroup == nil then
			chain = chain:andThen(function()
				return _ExecutePhase(currentPhase, elements, originalPositions, direction, createdScales)
			end)
			index = index + 1
		else
			-- Gather contiguous phases sharing the same group and run them together
			local groupedPhases = {}
			while index <= #phases and phases[index].ParallelGroup == parallelGroup do
				table.insert(groupedPhases, phases[index])
				index = index + 1
			end

			chain = chain:andThen(function()
				local phasePromises = {}
				for _, groupedPhase in groupedPhases do
					table.insert(
						phasePromises,
						_ExecutePhase(groupedPhase, elements, originalPositions, direction, createdScales)
					)
				end
				return Promise.all(phasePromises)
			end)
		end
	end

	return chain
end

-- Halt all active spring animations on elements (and their UIScale children)
local function _StopAllAnimations(elements: { [string]: GuiObject }): ()
	for _, child in elements do
		spr.stop(child)
		-- Also stop any UIScale children used for scale animations
		local uiScale = child:FindFirstChild("_TransitionScale")
		if uiScale then
			spr.stop(uiScale)
		end
	end
end

local function _DestroyCreatedScales(createdScales: { UIScale })
	for _, uiScale in createdScales do
		if uiScale and uiScale.Parent then
			uiScale:Destroy()
		end
	end
	table.clear(createdScales)
end

-- Entrance helpers

-- Show container immediately (no entrance animation) and signal completion
local function _ShowContainerImmediately(
	containerRef: { current: Frame? },
	transitionCtx: TransitionContext.TTransitionContext?
)
	task.defer(function()
		local container = containerRef.current
		if container then
			container.Visible = true
		end
		-- Signal to the router that entrance is complete
		if transitionCtx and transitionCtx.OnEntranceComplete then
			transitionCtx.OnEntranceComplete()
		end
	end)
end

-- Run entrance animation phases for the screen
local function _RunEnterAnimation(
	container: Frame,
	presetConfig: TPresetConfig,
	elementsRef: { current: { [string]: GuiObject } },
	originalPositionsRef: { current: { [string]: UDim2 } },
	createdScalesRef: { current: { UIScale } },
	transitionCtx: TransitionContext.TTransitionContext?,
	setIsEntering: (value: boolean) -> (),
	isCancelled: () -> boolean
): any
	-- Find animation targets in the container
	local elements = _FindElements(container, presetConfig.Elements)
	elementsRef.current = elements

	-- Snap elements to "from" state (starting positions for animation)
	local originalPositions, createdScales = _SnapToOrigins(presetConfig.Enter, elements)
	originalPositionsRef.current = originalPositions
	for _, scale in createdScales do
		table.insert(createdScalesRef.current, scale)
	end

	-- Reveal container and begin entrance animation
	container.Visible = true
	setIsEntering(true)

	return _ExecutePhases(
		presetConfig.Enter,
		elements,
		originalPositions,
		"enter",
		createdScalesRef.current
	)
		:andThen(function()
			-- Guard: cleanup may have cancelled this animation
			if isCancelled() then
				return
			end
			setIsEntering(false)
			-- Signal router that entrance is complete; router may unblock queued navigations
			if transitionCtx and transitionCtx.OnEntranceComplete then
				transitionCtx.OnEntranceComplete()
			end
		end)
		:catch(function(err)
			if not isCancelled() then
				setIsEntering(false)
				warn("[useScreenTransition] Enter error:", err)
			end
		end)
end

-- Run exit animation phases for the screen
local function _RunExitAnimation(
	exitPhases: { TPhase },
	elements: { [string]: GuiObject },
	originalPositionsRef: { current: { [string]: UDim2 } },
	createdScalesRef: { current: { UIScale } },
	setIsExiting: (value: boolean) -> (),
	isCancelled: () -> boolean,
	onComplete: () -> ()
): any
	setIsExiting(true)

	return _ExecutePhases(
		exitPhases,
		elements,
		originalPositionsRef.current,
		"exit",
		createdScalesRef.current
	)
		:andThen(function()
			if not isCancelled() then
				setIsExiting(false)
			end
			-- Signal router that exit is complete; router proceeds to mount new screen
			onComplete()
		end)
		:catch(function(err)
			if not isCancelled() then
				setIsExiting(false)
				warn("[useScreenTransition] Exit error:", err)
			end
			-- Signal completion even on error so router doesn't hang
			onComplete()
		end)
end

-- Main Hook

--[=[
	Set up enter and exit animations for a screen using the named preset from `TransitionPresets`.
	@within useScreenTransition
	@param presetName string -- Key into `TransitionPresets` (e.g. `"Standard"`, `"Simple"`).
	@return TScreenTransitionResult -- Container ref and entering/exiting state flags.
]=]
local function useScreenTransition(presetName: string): TScreenTransitionResult
	local prefersReducedMotion = useReducedMotion()
	local containerRef = useRef(nil :: Frame?)
	local transitionCtx = useContext(TransitionContext.Context)

	local isEntering, setIsEntering = useState(false)
	local isExiting, setIsExiting = useState(false)

	local presetConfig: TPresetConfig? = useMemo(function()
		local preset = TransitionPresets[presetName]
		if not preset then
			warn("[useScreenTransition] Unknown preset:", presetName)
		end
		return preset
	end, {})

	local createdScalesRef = useRef({} :: { UIScale })
	local elementsRef = useRef({} :: { [string]: GuiObject })
	local originalPositionsRef = useRef({} :: { [string]: UDim2 })

	-- Entrance animation: snap to hidden state, show container, run enter phases
	useEffect(function()
		if not presetConfig then
			_ShowContainerImmediately(containerRef, transitionCtx)
			return
		end

		local cancelled = false
		local isCancelled = function() return cancelled end
		local entrancePromise: any = nil

		-- Defer one frame to allow React to render container before animating
		local deferThread = task.defer(function()
			if cancelled then
				return
			end

			local container = containerRef.current
			if not container then
				return
			end

			-- Respect reduced motion preferences; show immediately
			if prefersReducedMotion then
				container.Visible = true
				if transitionCtx and transitionCtx.OnEntranceComplete then
					transitionCtx.OnEntranceComplete()
				end
				return
			end

			-- No entrance phases configured; show immediately
			local enterPhases = presetConfig.Enter
			if not enterPhases or #enterPhases == 0 then
				container.Visible = true
				if transitionCtx and transitionCtx.OnEntranceComplete then
					transitionCtx.OnEntranceComplete()
				end
				return
			end

			-- Run the entrance animation
			entrancePromise = _RunEnterAnimation(
				container,
				presetConfig,
				elementsRef,
				originalPositionsRef,
				createdScalesRef,
				transitionCtx,
				setIsEntering,
				isCancelled
			)
		end)

		-- Cleanup: cancel animations and dispose resources if the hook unmounts
		return function()
			cancelled = true
			task.cancel(deferThread)
			if entrancePromise then
				entrancePromise:cancel()
			end
			_StopAllAnimations(elementsRef.current)
			_DestroyCreatedScales(createdScalesRef.current)
		end
	end, {})

	-- Register exit animation handler with the router
	useEffect(function()
		if not transitionCtx or not transitionCtx.RegisterExit then
			return
		end
		if not presetConfig then
			return
		end

		-- No exit phases configured; skip registration
		local exitPhases = presetConfig.Exit
		if not exitPhases or #exitPhases == 0 then
			return
		end
		-- Respect reduced motion; skip exit animation
		if prefersReducedMotion then
			return
		end

		local cancelled = false
		local isCancelled = function() return cancelled end
		local exitPromise: any = nil

		-- Register the exit handler (called by router when navigation occurs)
		transitionCtx.RegisterExit(function(onComplete: () -> ())
			if cancelled then
				onComplete()
				return
			end

			local elements = elementsRef.current
			if not elements or next(elements) == nil then
				onComplete()
				return
			end

			-- Run the exit animation
			exitPromise = _RunExitAnimation(
				exitPhases,
				elements,
				originalPositionsRef,
				createdScalesRef,
				setIsExiting,
				isCancelled,
				onComplete
			)
		end)

		-- Cleanup: cancel exit animation if the hook unmounts
		return function()
			cancelled = true
			if exitPromise then
				exitPromise:cancel()
			end
			_StopAllAnimations(elementsRef.current)
		end
	end, { transitionCtx })

	return {
		containerRef = containerRef,
		isEntering = isEntering,
		isExiting = isExiting,
	}
end

return useScreenTransition
