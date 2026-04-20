--!strict
--[=[
	@class GameHUD
	Organism that composes the top bar and side menu panel, managing visibility and navigation state.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useScreenTransition = require(script.Parent.Parent.Parent.Application.Hooks.useScreenTransition)
local TopBar = require(script.Parent.Parent.Molecules.TopBar)
local SidePanel = require(script.Parent.SidePanel)

export type TGameHUDProps = {
	IsMenuOpen: boolean,
	OnToggleMenu: () -> (),
	OnNavigateFromMenu: (featureName: string) -> (),
	OnOpenSettings: () -> (),
	OnExitGame: () -> (),
	PlayerUsername: string,
	PlayerLevel: number,
}

local function GameHUD(props: TGameHUDProps)
	local anim = useScreenTransition("HUD")

	local children = {
		Header = e(TopBar, {
			OnToggleMenu = props.OnToggleMenu,
			OnOpenSettings = props.OnOpenSettings,
			PlayerUsername = props.PlayerUsername,
			PlayerLevel = props.PlayerLevel,
		}),
	}

	-- Only render SidePanel when menu should be visible
	if props.IsMenuOpen then
		children.SidePanelComponent = e(SidePanel, {
			OnNavigateFromMenu = props.OnNavigateFromMenu,
			OnExitGame = props.OnExitGame,
		})
	end

	return e("Frame", {
		ref = anim.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
		ClipsDescendants = false,
	}, children)
end

return GameHUD
