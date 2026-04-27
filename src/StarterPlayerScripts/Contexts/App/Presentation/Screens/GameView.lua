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
local useScreenTransition = require(script.Parent.Parent.Parent.Application.Hooks.useScreenTransition)
local GameViewView = require(script.Parent.GameViewView)

local function GameView()
	local controller = useGameViewController()
	local anim = useScreenTransition("Simple")

	return e(GameViewView, {
		containerRef = anim.containerRef,
		isMenuOpen = controller.isMenuOpen,
		isHudEnabled = controller.isHudEnabled,
		isRunActive = controller.isRunActive,
		onToggleMenu = controller.onToggleMenu,
		onNavigateFromMenu = controller.onNavigateFromMenu,
		onOpenSettings = controller.onOpenSettings,
		onExitGame = controller.onExitGame,
		onStartPhase2 = controller.onStartPhase2,
		onStructureSelected = controller.onStructureSelected,
		isInventoryOpen = controller.isInventoryOpen,
		onToggleInventory = controller.onToggleInventory,
		onCloseInventory = controller.onCloseInventory,
		playerUsername = controller.playerUsername,
		playerLevel = controller.playerLevel,
	})
end

return GameView
