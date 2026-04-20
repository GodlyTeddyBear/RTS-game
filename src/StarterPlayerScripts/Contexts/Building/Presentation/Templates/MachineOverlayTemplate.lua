--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useMachineOverlayController = require(script.Parent.Parent.Parent.Application.Hooks.useMachineOverlayController)
local MachineOverlayView = require(script.Parent.Parent.Organisms.MachineOverlayView)

local e = React.createElement

--[=[
	@class MachineOverlayTemplate
	Renders the machine overlay UI using controller state.
	@client
]=]
local function MachineOverlayTemplate()
	local controller = useMachineOverlayController()

	return e(MachineOverlayView, {
		isOpen = controller.isOpen,
		panelRef = controller.panelRef,
		popupPanelRef = controller.popupPanelRef,
		outputPopupPanelRef = controller.outputPopupPanelRef,
		titleText = controller.titleText,
		subtitleText = controller.subtitleText,
		fuelSeconds = controller.fuelSeconds,
		fuelRatio = controller.fuelRatio,
		queueRows = controller.queueRows,
		outputEntries = controller.outputEntries,
		isActionMenuOpen = controller.isActionMenuOpen,
		isOutputMenuOpen = controller.isOutputMenuOpen,
		actionMenuButtonText = controller.actionMenuButtonText,
		outputButtonText = controller.outputButtonText,
		statusTitleText = controller.statusTitleText,
		statusMetricLabelText = controller.statusMetricLabelText,
		queueTitleText = controller.queueTitleText,
		queueEmptyText = controller.queueEmptyText,
		actionsTitleText = controller.actionsTitleText,
		actionPopupTitleText = controller.actionPopupTitleText,
		outputPopupTitleText = controller.outputPopupTitleText,
		outputPopupEmptyText = controller.outputPopupEmptyText,
		actionItems = controller.actionItems,
		actionErrorFlashKey = controller.actionErrorFlashKey,
		actionErrorFlashGeneration = controller.actionErrorFlashGeneration,
		onCloseOverlay = controller.onCloseOverlay,
		onToggleActionMenu = controller.onToggleActionMenu,
		onOpenOutputMenu = controller.onOpenOutputMenu,
		onCloseActionMenu = controller.onCloseActionMenu,
		onCloseOutputMenu = controller.onCloseOutputMenu,
	})
end

return MachineOverlayTemplate
