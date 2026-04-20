--!strict
--[=[
	@class GameViewView
	Wrapper screen connecting GameView to the game view controller and child feature screens.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local GameHUD = require(script.Parent.Parent.Organisms.GameHUD)
local NPCCommandPresentation = require(script.Parent.Parent.Parent.Parent.NPCCommand.Presentation)
local DialoguePresentation = require(script.Parent.Parent.Parent.Parent.Dialogue.Presentation)

type TGameViewViewProps = {
	isMenuOpen: boolean,
	isHudEnabled: boolean,
	onToggleMenu: () -> (),
	onNavigateFromMenu: (string) -> (),
	onOpenSettings: () -> (),
	onExitGame: () -> (),
	playerUsername: string,
	playerLevel: number,
}

local function GameViewView(props: TGameViewViewProps)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		HUDOverlay = if props.isHudEnabled then e(GameHUD, {
			IsMenuOpen = props.isMenuOpen,
			OnToggleMenu = props.onToggleMenu,
			OnNavigateFromMenu = props.onNavigateFromMenu,
			OnOpenSettings = props.onOpenSettings,
			OnExitGame = props.onExitGame,
			PlayerUsername = props.playerUsername,
			PlayerLevel = props.playerLevel,
		}) else nil,
		NPCCommandOverlay = e(NPCCommandPresentation.NPCCommandScreen),
		DialogueOverlay = e(DialoguePresentation.DialogueOverlay),
	})
end

return GameViewView
