--!strict
--[=[
	@class useHomeScreenController
	React hook that manages the Home screen's enter animation, blur effect, and play button logic.
	@client
]=]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState

local useNavigationActions = require(script.Parent.useNavigationActions)
local useScreenTransition = require(script.Parent.useScreenTransition)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)

local BLUR_EFFECT_NAME = "HomeMenuBlur"
local MEDIUM_BLUR_SIZE = 16
local GAME_SCREEN = "Game"
local HOME_MENU_SOUND_TARGET = "Home"
local HOME_PLAY_VARIANT = "home_play"

type TNavigationActions = typeof(useNavigationActions())
type TSoundActions = typeof(useSoundActions())

type TValueRef<T> = { current: T }

--[=[
	@interface THomeScreenController
	@within useHomeScreenController
	.containerRef { current: Frame? } -- Ref to attach to the screen's root `Frame`.
	.isPlaying boolean -- Whether the play button animation is currently running.
	.onPlayStart () -> () -- Called when the play button is clicked.
	.onPlayHover () -> () -- Called when the mouse enters the play button.
	.onPlayComplete () -> () -- Called when the play animation completes.
]=]
export type THomeScreenController = {
	containerRef: { current: Frame? },
	isPlaying: boolean,
	onPlayStart: () -> (),
	onPlayHover: () -> (),
	onPlayComplete: () -> (),
}

local function _ApplyHomeBlur(): () -> ()
	local blur = Lighting:FindFirstChild(BLUR_EFFECT_NAME)
	local createdLocally = false
	local previousSize = 0
	local blurEffect: BlurEffect

	if blur and blur:IsA("BlurEffect") then
		blurEffect = blur
		previousSize = blurEffect.Size
	else
		createdLocally = true
		blurEffect = Instance.new("BlurEffect")
		blurEffect.Name = BLUR_EFFECT_NAME
		blurEffect.Parent = Lighting
	end

	blurEffect.Size = MEDIUM_BLUR_SIZE

	return function()
		if createdLocally and blurEffect.Parent then
			blurEffect:Destroy()
		elseif blurEffect.Parent then
			blurEffect.Size = previousSize
		end
	end
end

local function _StartGameFlow(
	soundActionsRef: TValueRef<TSoundActions>,
	actionsRef: TValueRef<TNavigationActions>
)
	soundActionsRef.current.playMenuClose(HOME_MENU_SOUND_TARGET)
	actionsRef.current.navigate(GAME_SCREEN)
end

local function _CreatePlayStartHandler(
	isPlayingRef: TValueRef<boolean>,
	setIsPlaying: (boolean) -> (),
	soundActionsRef: TValueRef<TSoundActions>
): () -> ()
	return function()
		if isPlayingRef.current then
			return
		end

		setIsPlaying(true)
		soundActionsRef.current.playButtonClick(HOME_PLAY_VARIANT)
	end
end

local function _CreatePlayCompleteHandler(
	soundActionsRef: TValueRef<TSoundActions>,
	actionsRef: TValueRef<TNavigationActions>
): () -> ()
	return function()
		_StartGameFlow(soundActionsRef, actionsRef)
	end
end

local function _CreatePlayHoverHandler(soundActionsRef: TValueRef<TSoundActions>): () -> ()
	return function()
		soundActionsRef.current.playMenuOpen("HomePlayHover")
	end
end

--[=[
	Return a controller object managing the Home screen's animations and play button state.
	@within useHomeScreenController
	@return THomeScreenController -- Screen container ref and play state handlers.
]=]
local function useHomeScreenController(): THomeScreenController
	local anim = useScreenTransition("Simple")
	local actions = useNavigationActions()
	local soundActions = useSoundActions()
	local isPlaying, setIsPlaying = useState(false)
	local actionsRef = useRef(actions)
	local soundActionsRef = useRef(soundActions)
	local isPlayingRef = useRef(isPlaying)

	actionsRef.current = actions
	soundActionsRef.current = soundActions
	isPlayingRef.current = isPlaying

	useEffect(function()
		return _ApplyHomeBlur()
	end, {})

	local onPlayStart = useMemo(function()
		return _CreatePlayStartHandler(isPlayingRef, setIsPlaying, soundActionsRef)
	end, {})

	local onPlayHover = useMemo(function()
		return _CreatePlayHoverHandler(soundActionsRef)
	end, {})

	local onPlayComplete = useMemo(function()
		return _CreatePlayCompleteHandler(soundActionsRef, actionsRef)
	end, {})

	return {
		containerRef = anim.containerRef,
		isPlaying = isPlaying,
		onPlayStart = onPlayStart,
		onPlayHover = onPlayHover,
		onPlayComplete = onPlayComplete,
	}
end

return useHomeScreenController
