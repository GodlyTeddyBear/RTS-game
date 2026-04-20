--!strict
--[=[
	@class useHomePlayButtonController
	React hook that coordinates the Home play button's pulse animation, hover effects, and press sequence.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef

local PULSE_UP_DURATION = 1.05
local PULSE_DOWN_DURATION = 1.05
local PRESSED_SCALE = 0.94
local PRESSED_DURATION = 0.08
local BOUNCE_SCALE = 1.08
local BOUNCE_DURATION = 0.11
local RELEASE_SCALE = 1
local RELEASE_DURATION = 0.09
local HOVER_DURATION = 0.12
local HOVER_SCALE = 1.08
local SHIMMER_DURATION = 1.3
local PLAY_SCALE_NAME = "PlayScale"

--[=[
	@interface THomePlayButtonController
	@within useHomePlayButtonController
	.buttonRef { current: TextButton? } -- Ref to the play button `TextButton`.
	.shimmerRef { current: UIGradient? } -- Ref to the shimmer `UIGradient` child.
	.onActivated () -> () -- Called when the button is clicked.
	.onMouseEnter () -> () -- Called when the mouse enters the button.
	.onMouseLeave () -> () -- Called when the mouse leaves the button.
]=]
export type THomePlayButtonController = {
	buttonRef: { current: TextButton? },
	shimmerRef: { current: UIGradient? },
	onActivated: () -> (),
	onMouseEnter: () -> (),
	onMouseLeave: () -> (),
}

local function _PlayScaleTween(playScale: UIScale, duration: number, scale: number, easingStyle: Enum.EasingStyle, easingDirection: Enum.EasingDirection)
	TweenService:Create(playScale, TweenInfo.new(duration, easingStyle, easingDirection), {
		Scale = scale,
	}):Play()
end

local function _FindOrCreatePlayScale(playButton: TextButton): UIScale
	local existingScale = playButton:FindFirstChild(PLAY_SCALE_NAME)
	if existingScale and existingScale:IsA("UIScale") then
		return existingScale
	end

	local playScale = Instance.new("UIScale")
	playScale.Name = PLAY_SCALE_NAME
	playScale.Scale = RELEASE_SCALE
	playScale.Parent = playButton
	return playScale
end

local function _StartPulseLoop(playButton: TextButton, playScale: UIScale, isPlayingRef: { current: boolean }): thread
	return task.spawn(function()
		while playButton.Parent do
			if isPlayingRef.current then
				task.wait(0.1)
				continue
			end

			_PlayScaleTween(playScale, PULSE_UP_DURATION, 1.04, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(PULSE_UP_DURATION)
			_PlayScaleTween(playScale, PULSE_DOWN_DURATION, RELEASE_SCALE, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(PULSE_DOWN_DURATION)
		end
	end)
end

local function _CreateHoverEnterHandler(
	playScaleRef: { current: UIScale? },
	isPlayingRef: { current: boolean },
	onPlayHoverRef: { current: () -> () }
): () -> ()
	return function()
		if isPlayingRef.current then
			return
		end

		onPlayHoverRef.current()
		local playScale = playScaleRef.current
		if playScale then
			_PlayScaleTween(playScale, HOVER_DURATION, HOVER_SCALE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
	end
end

local function _CreateHoverLeaveHandler(playScaleRef: { current: UIScale? }, isPlayingRef: { current: boolean }): () -> ()
	return function()
		if isPlayingRef.current then
			return
		end

		local playScale = playScaleRef.current
		if playScale then
			_PlayScaleTween(playScale, HOVER_DURATION, RELEASE_SCALE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		end
	end
end

local function _CreateActivatedHandler(
	isPlayingRef: { current: boolean },
	onPlayStartRef: { current: () -> () },
	onPlayCompleteRef: { current: () -> () },
	playScaleRef: { current: UIScale? },
	pressThreadRef: { current: thread? }
): () -> ()
	return function()
		if isPlayingRef.current then
			return
		end

		onPlayStartRef.current()
		local playScale = playScaleRef.current
		pressThreadRef.current = task.spawn(function()
			if playScale then
				_PlayScaleTween(playScale, PRESSED_DURATION, PRESSED_SCALE, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				task.wait(PRESSED_DURATION)
				_PlayScaleTween(playScale, BOUNCE_DURATION, BOUNCE_SCALE, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				task.wait(BOUNCE_DURATION)
				_PlayScaleTween(playScale, RELEASE_DURATION, RELEASE_SCALE, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			end

			onPlayCompleteRef.current()
			pressThreadRef.current = nil
		end)
	end
end

--[=[
	Coordinate the play button's animations and manage refs to the button and shimmer gradient.
	@within useHomePlayButtonController
	@param isPlaying boolean -- Whether the play button animation is currently running.
	@param onPlayStart () -> () -- Callback fired when the button is clicked.
	@param onPlayHover () -> () -- Callback fired when the mouse enters the button.
	@param onPlayComplete () -> () -- Callback fired when the play animation completes.
	@return THomePlayButtonController -- Button ref, shimmer ref, and event handlers.
]=]
local function useHomePlayButtonController(
	isPlaying: boolean,
	onPlayStart: () -> (),
	onPlayHover: () -> (),
	onPlayComplete: () -> ()
): THomePlayButtonController
	local buttonRef = useRef(nil :: TextButton?)
	local playScaleRef = useRef(nil :: UIScale?)
	local shimmerRef = useRef(nil :: UIGradient?)
	local pulseThreadRef = useRef(nil :: thread?)
	local pressThreadRef = useRef(nil :: thread?)
	local isPlayingRef = useRef(isPlaying)
	local onPlayStartRef = useRef(onPlayStart)
	local onPlayHoverRef = useRef(onPlayHover)
	local onPlayCompleteRef = useRef(onPlayComplete)

	isPlayingRef.current = isPlaying
	onPlayStartRef.current = onPlayStart
	onPlayHoverRef.current = onPlayHover
	onPlayCompleteRef.current = onPlayComplete

	useEffect(function()
		local playButton = buttonRef.current
		if not playButton then
			return
		end

		local playScale = _FindOrCreatePlayScale(playButton)
		playScaleRef.current = playScale

		local shimmer = shimmerRef.current
		if not shimmer then
			return
		end

		local shimmerTween = TweenService:Create(
			shimmer,
			TweenInfo.new(SHIMMER_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Offset = Vector2.new(1, 0) }
		)
		shimmer.Offset = Vector2.new(-1, 0)
		shimmerTween:Play()

		pulseThreadRef.current = _StartPulseLoop(playButton, playScale, isPlayingRef)

		return function()
			shimmerTween:Cancel()
			if pulseThreadRef.current then
				task.cancel(pulseThreadRef.current)
				pulseThreadRef.current = nil
			end
		end
	end, {})

	useEffect(function()
		return function()
			if pressThreadRef.current then
				task.cancel(pressThreadRef.current)
				pressThreadRef.current = nil
			end
		end
	end, {})

	local onMouseEnter = useMemo(function()
		return _CreateHoverEnterHandler(playScaleRef, isPlayingRef, onPlayHoverRef)
	end, {})

	local onMouseLeave = useMemo(function()
		return _CreateHoverLeaveHandler(playScaleRef, isPlayingRef)
	end, {})

	local onActivated = useMemo(function()
		return _CreateActivatedHandler(isPlayingRef, onPlayStartRef, onPlayCompleteRef, playScaleRef, pressThreadRef)
	end, {})

	return {
		buttonRef = buttonRef,
		shimmerRef = shimmerRef,
		onActivated = onActivated,
		onMouseEnter = onMouseEnter,
		onMouseLeave = onMouseLeave,
	}
end

return useHomePlayButtonController
