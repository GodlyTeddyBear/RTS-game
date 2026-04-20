--!strict
--[=[
	@class useGameViewController
	React hook that manages the Game screen's menu and navigation state, handling feature selection, settings, and exit.
	@client
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useMemo = React.useMemo
local useRef = React.useRef
local useState = React.useState

local useNavigationActions = require(script.Parent.useNavigationActions)
local useHudVisibility = require(script.Parent.useHudVisibility)
local useSoundActions = require(script.Parent.Parent.Parent.Parent.Sound.Application.Hooks.useSoundActions)
local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)

-- Duration before navigating after menu close, derived from the Smooth spring preset.
local MENU_CLOSE_DURATION = 1 / AnimationTokens.Spring.Smooth.Frequency
local SIDE_PANEL_SOUND_TARGET = "SidePanel"
local GAME_SCREEN = "Game"
local SETTINGS_SCREEN = "Settings"

type TNavigationActions = typeof(useNavigationActions())
type TSoundActions = typeof(useSoundActions())

type TSetBooleanState = (boolean | ((boolean) -> boolean)) -> ()
type TThreadRef = { current: thread? }
type TValueRef<T> = { current: T }

--[=[
	@interface TGameViewController
	@within useGameViewController
	.isMenuOpen boolean -- Whether the side menu panel is currently displayed.
	.isHudEnabled boolean -- Whether the main game HUD should be rendered.
	.onToggleMenu () -> () -- Toggle menu visibility.
	.onNavigateToFeature (featureName: string) -> () -- Close menu and navigate to a feature screen after delay.
	.onNavigateFromMenu (featureName: string) -> () -- Switch tabs within the open menu and play sound.
	.onOpenSettings () -> () -- Navigate to the Settings screen from the menu.
	.onExitGame () -> () -- Exit to the Game screen and close the menu.
	.playerUsername string -- The current player's username.
	.playerLevel number -- The current player's level.
]=]
export type TGameViewController = {
	isMenuOpen: boolean,
	isHudEnabled: boolean,
	onToggleMenu: () -> (),
	onNavigateToFeature: (featureName: string) -> (),
	onNavigateFromMenu: (featureName: string) -> (),
	onOpenSettings: () -> (),
	onExitGame: () -> (),
	playerUsername: string,
	playerLevel: number,
}

local function _GetPlayerInfo(): (string, number)
	local player = Players.LocalPlayer
	local playerUsername = player.Name
	local playerLevel = 1 -- TODO: Get from PlayerDataService when implemented.
	return playerUsername, playerLevel
end

local function _CloseMenu(setIsMenuOpen: TSetBooleanState, soundActions: TSoundActions)
	setIsMenuOpen(function(prev: boolean)
		if prev then
			soundActions.playMenuClose(SIDE_PANEL_SOUND_TARGET)
		end
		return false
	end)
end

local function _ToggleMenu(setIsMenuOpen: TSetBooleanState, soundActions: TSoundActions)
	setIsMenuOpen(function(prev: boolean)
		if prev then
			soundActions.playMenuClose(SIDE_PANEL_SOUND_TARGET)
		else
			soundActions.playMenuOpen(SIDE_PANEL_SOUND_TARGET)
		end
		return not prev
	end)
end

local function _CancelPendingNavigation(pendingNavigationRef: TThreadRef)
	local pendingThread = pendingNavigationRef.current
	if pendingThread then
		task.cancel(pendingThread)
		pendingNavigationRef.current = nil
	end
end

local function _NavigateToFeature(
	actions: TNavigationActions,
	featureName: string,
	pendingNavigationRef: TThreadRef
)
	_CancelPendingNavigation(pendingNavigationRef)
	pendingNavigationRef.current = task.delay(MENU_CLOSE_DURATION, function()
		pendingNavigationRef.current = nil
		actions.navigate(featureName)
	end)
end

local function _ExitToGame(actions: TNavigationActions)
	actions.reset(GAME_SCREEN)
end

local function _NavigateToMenuFeature(
	featureName: string,
	soundActions: TSoundActions,
	navigateToFeature: (featureName: string) -> ()
)
	soundActions.playTabSwitch(featureName)
	navigateToFeature(featureName)
end

local function _CreateToggleMenuHandler(
	setIsMenuOpen: TSetBooleanState,
	soundActionsRef: TValueRef<TSoundActions>
): () -> ()
	return function()
		_ToggleMenu(setIsMenuOpen, soundActionsRef.current)
	end
end

local function _CreateNavigateToFeatureHandler(
	setIsMenuOpen: TSetBooleanState,
	soundActionsRef: TValueRef<TSoundActions>,
	actionsRef: TValueRef<TNavigationActions>,
	pendingNavigationRef: TThreadRef
): (featureName: string) -> ()
	return function(featureName: string)
		_CloseMenu(setIsMenuOpen, soundActionsRef.current)
		_NavigateToFeature(actionsRef.current, featureName, pendingNavigationRef)
	end
end

local function _CreateExitGameHandler(actionsRef: TValueRef<TNavigationActions>): () -> ()
	return function()
		_ExitToGame(actionsRef.current)
	end
end

local function _CreateNavigateFromMenuHandler(
	soundActionsRef: TValueRef<TSoundActions>,
	navigateToFeature: (featureName: string) -> ()
): (featureName: string) -> ()
	return function(featureName: string)
		_NavigateToMenuFeature(featureName, soundActionsRef.current, navigateToFeature)
	end
end

local function _CreateOpenSettingsHandler(navigateFromMenu: (featureName: string) -> ()): () -> ()
	return function()
		navigateFromMenu(SETTINGS_SCREEN)
	end
end

--[=[
	Return a controller object managing menu state and navigation for the Game screen.
	@within useGameViewController
	@return TGameViewController -- Menu state and navigation action handlers.
]=]
local function useGameViewController(): TGameViewController
	local actions = useNavigationActions()
	local hudVisibility = useHudVisibility()
	local soundActions = useSoundActions()
	local isMenuOpen, setIsMenuOpen = useState(false)
	local actionsRef = useRef(actions)
	local soundActionsRef = useRef(soundActions)
	local pendingNavigationRef = useRef(nil :: thread?)

	actionsRef.current = actions
	soundActionsRef.current = soundActions

	useEffect(function()
		return function()
			_CancelPendingNavigation(pendingNavigationRef)
		end
	end, {})

	useEffect(function()
		if hudVisibility.IsGameHudEnabled then
			return
		end

		setIsMenuOpen(false)
		_CancelPendingNavigation(pendingNavigationRef)
	end, { hudVisibility.IsGameHudEnabled })

	local playerUsername, playerLevel = _GetPlayerInfo()
	local onToggleMenu = useMemo(function()
		return _CreateToggleMenuHandler(setIsMenuOpen, soundActionsRef)
	end, {})
	local onNavigateToFeature = useMemo(function()
		return _CreateNavigateToFeatureHandler(setIsMenuOpen, soundActionsRef, actionsRef, pendingNavigationRef)
	end, {})
	local onNavigateFromMenu = useMemo(function()
		return _CreateNavigateFromMenuHandler(soundActionsRef, onNavigateToFeature)
	end, { onNavigateToFeature })
	local onOpenSettings = useMemo(function()
		return _CreateOpenSettingsHandler(onNavigateFromMenu)
	end, { onNavigateFromMenu })
	local onExitGame = useMemo(function()
		return _CreateExitGameHandler(actionsRef)
	end, {})

	return {
		isMenuOpen = isMenuOpen,
		isHudEnabled = hudVisibility.IsGameHudEnabled,
		onToggleMenu = onToggleMenu,
		onNavigateToFeature = onNavigateToFeature,
		onNavigateFromMenu = onNavigateFromMenu,
		onOpenSettings = onOpenSettings,
		onExitGame = onExitGame,
		playerUsername = playerUsername,
		playerLevel = playerLevel,
	}
end

return useGameViewController
