--!strict
--[=[
	@class SidePanel
	Organism composed of a menu list and exit button with animated slide-in entrance.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local useSidePanelController = require(script.Parent.Parent.Parent.Application.Hooks.useSidePanelController)
local SidePanelView = require(script.Parent.SidePanelView)

export type TSidePanelProps = {
	OnNavigateFromMenu: (featureName: string) -> (),
	OnExitGame: () -> (),
}

local function SidePanel(props: TSidePanelProps)
	local controller = useSidePanelController(props.OnExitGame)

	return e(SidePanelView, {
		panelRef = controller.panelRef,
		exitRef = controller.exitRef,
		onExitMouseEnter = controller.onExitMouseEnter,
		onExitMouseLeave = controller.onExitMouseLeave,
		onExitActivated = controller.onExitActivated,
		onNavigateFromMenu = props.OnNavigateFromMenu,
	})
end

return SidePanel
