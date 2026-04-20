--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useReducedMotion = require(script.Parent.Parent.Parent.Parent.Parent.App.Application.Hooks.useReducedMotion)
local useTween = require(script.Parent.Parent.Parent.Parent.Parent.App.Application.Hooks.useTween)

local useEffect = React.useEffect
local useRef = React.useRef

-- Panel animation endpoints
local PANEL_TARGET_POSITION = UDim2.fromScale(0.5, 0.55)
local PANEL_HIDDEN_POSITION = UDim2.fromScale(0.5, 0.74)
-- Popup animation endpoints
local POPUP_TARGET_POSITION = UDim2.fromScale(0.5, 0.54)
local POPUP_HIDDEN_POSITION = UDim2.fromScale(0.5, 0.72)

--[=[
	@type TMachineOverlayAnimationRefs
	@within useMachineOverlayAnimations
	.panelRef { current: Frame? } -- Main overlay panel reference
	.popupPanelRef { current: Frame? } -- Action menu popup reference
	.outputPopupPanelRef { current: Frame? } -- Output menu popup reference
]=]
export type TMachineOverlayAnimationRefs = {
	panelRef: { current: Frame? },
	popupPanelRef: { current: Frame? },
	outputPopupPanelRef: { current: Frame? },
}

--[=[
	Manages animation refs and tweens for main panel and popup menus.
	Respects `prefers-reduced-motion` and instantly positions frames when enabled.
	@within useMachineOverlayAnimations
	@param isOpen boolean -- Whether the main overlay is open
	@param isActionMenuOpen boolean -- Whether the action menu popup is open
	@param isOutputMenuOpen boolean -- Whether the output menu popup is open
	@return TMachineOverlayAnimationRefs -- Refs for panel and popup elements
]=]
local function useMachineOverlayAnimations(
	isOpen: boolean,
	isActionMenuOpen: boolean,
	isOutputMenuOpen: boolean
): TMachineOverlayAnimationRefs
	local panelRef = useRef(nil :: Frame?)
	local popupPanelRef = useRef(nil :: Frame?)
	local outputPopupPanelRef = useRef(nil :: Frame?)
	local prefersReducedMotion = useReducedMotion()
	local tween = useTween()

	useEffect(function()
		if not isOpen then
			return
		end

		local panel = panelRef.current
		if not panel then
			return
		end

		if prefersReducedMotion then
			panel.Position = PANEL_TARGET_POSITION
			return
		end

		panel.Position = PANEL_HIDDEN_POSITION
		tween(panelRef, {
			Position = PANEL_TARGET_POSITION,
		}, {
			Duration = 0.3,
			EasingStyle = Enum.EasingStyle.Quart,
			EasingDirection = Enum.EasingDirection.Out,
		})
	end, { isOpen, prefersReducedMotion, tween } :: { any })

	useEffect(function()
		if not isActionMenuOpen then
			return
		end

		local popupPanel = popupPanelRef.current
		if not popupPanel then
			return
		end

		if prefersReducedMotion then
			popupPanel.Position = POPUP_TARGET_POSITION
			return
		end

		popupPanel.Position = POPUP_HIDDEN_POSITION
		tween(popupPanelRef, {
			Position = POPUP_TARGET_POSITION,
		}, {
			Duration = 0.24,
			EasingStyle = Enum.EasingStyle.Quart,
			EasingDirection = Enum.EasingDirection.Out,
		})
	end, { isActionMenuOpen, prefersReducedMotion, tween } :: { any })

	useEffect(function()
		if not isOutputMenuOpen then
			return
		end

		local popupPanel = outputPopupPanelRef.current
		if not popupPanel then
			return
		end

		if prefersReducedMotion then
			popupPanel.Position = POPUP_TARGET_POSITION
			return
		end

		popupPanel.Position = POPUP_HIDDEN_POSITION
		tween(outputPopupPanelRef, {
			Position = POPUP_TARGET_POSITION,
		}, {
			Duration = 0.24,
			EasingStyle = Enum.EasingStyle.Quart,
			EasingDirection = Enum.EasingDirection.Out,
		})
	end, { isOutputMenuOpen, prefersReducedMotion, tween } :: { any })

	return {
		panelRef = panelRef,
		popupPanelRef = popupPanelRef,
		outputPopupPanelRef = outputPopupPanelRef,
	}
end

return useMachineOverlayAnimations
