--!strict
--[=[
	@class GameView
	Main game screen displaying the HUD with top bar and feature content area.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useGameViewController = require(script.Parent.Parent.Parent.Application.Hooks.useGameViewController)
local GameViewView = require(script.Parent.GameViewView)

local function GameView()
	local controller = useGameViewController()

	return e(GameViewView, {
		isMenuOpen = controller.isMenuOpen,
		isHudEnabled = controller.isHudEnabled,
		isRunActive = controller.isRunActive,
		onToggleMenu = controller.onToggleMenu,
		onNavigateFromMenu = controller.onNavigateFromMenu,
		onOpenSettings = controller.onOpenSettings,
		onExitGame = controller.onExitGame,
		playerUsername = controller.playerUsername,
		playerLevel = controller.playerLevel,
	})
end

return GameView
