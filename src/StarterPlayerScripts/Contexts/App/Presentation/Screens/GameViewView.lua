--!strict
--[=[
	@class GameViewView
	Wrapper screen connecting GameView to the game view controller and child feature screens.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement
local RunPresentation = require(script.Parent.Parent.Parent.Parent.Run.Presentation)

type TGameViewViewProps = {
	isMenuOpen: boolean,
	isHudEnabled: boolean,
	isRunActive: boolean,
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
		RunHUD = props.isHudEnabled and props.isRunActive and e(RunPresentation.RunHUD) or nil,
	})
end

return GameViewView
