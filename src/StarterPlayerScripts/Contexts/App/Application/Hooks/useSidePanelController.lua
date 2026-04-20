--!strict
--[=[
	@class useSidePanelController
	React hook that manages side panel slide-in animation and exit button hover state.
	@client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useEffect = React.useEffect
local useRef = React.useRef

local useSpring = require(script.Parent.useSpring)
local useReducedMotion = require(script.Parent.useReducedMotion)
local AnimationTokens = require(script.Parent.Parent.Parent.Config.AnimationTokens)
local useHoverSpring = require(script.Parent.useHoverSpring)

local PANEL_WIDTH_SCALE = 0.208
local PANEL_MARGIN_LEFT_SCALE = 0.022
local TARGET_Y = 0.425
local HIDDEN_X = -0.15
local TARGET_X = PANEL_WIDTH_SCALE / 2 + PANEL_MARGIN_LEFT_SCALE

--[=[
	@interface TSidePanelController
	@within useSidePanelController
	.panelRef { current: Frame? } -- Ref to the side panel `Frame`.
	.exitRef { current: TextButton? } -- Ref to the exit button `TextButton`.
	.onExitMouseEnter () -> () -- Called when the mouse enters the exit button.
	.onExitMouseLeave () -> () -- Called when the mouse leaves the exit button.
	.onExitActivated () -> () -- Called when the exit button is clicked.
]=]
export type TSidePanelController = {
	panelRef: { current: Frame? },
	exitRef: { current: TextButton? },
	onExitMouseEnter: () -> (),
	onExitMouseLeave: () -> (),
	onExitActivated: () -> (),
}

--[=[
	Manage the side panel's slide-in animation and exit button hover/click events.
	@within useSidePanelController
	@param onExitGame () -> () -- Callback fired when the exit button is activated.
	@return TSidePanelController -- Panel ref, exit ref, and event handlers.
]=]
local function useSidePanelController(onExitGame: () -> ()): TSidePanelController
	local spring = useSpring()
	local prefersReducedMotion = useReducedMotion()
	local panelRef = useRef(nil :: Frame?)
	local exitRef = useRef(nil :: TextButton?)
	local exitHover = useHoverSpring(exitRef, AnimationTokens.Interaction.ActionButton)

	useEffect(function()
		local panel = panelRef.current
		if not panel then
			return
		end

		local targetPosition = UDim2.fromScale(TARGET_X, TARGET_Y)
		if prefersReducedMotion then
			panel.Position = targetPosition
			return
		end

		panel.Position = UDim2.fromScale(HIDDEN_X, TARGET_Y)
		spring(panelRef, {
			Position = targetPosition,
		}, "Smooth")
	end, { prefersReducedMotion })

	return {
		panelRef = panelRef,
		exitRef = exitRef,
		onExitMouseEnter = exitHover.onMouseEnter,
		onExitMouseLeave = exitHover.onMouseLeave,
		onExitActivated = exitHover.onActivated(onExitGame),
	}
end

return useSidePanelController
