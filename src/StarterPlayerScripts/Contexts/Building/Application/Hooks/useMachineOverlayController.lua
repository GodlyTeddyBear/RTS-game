--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactCharm = require(ReplicatedStorage.Packages["React-charm"])
local Knit = require(ReplicatedStorage.Packages.Knit)

local MachineUIAtom = require(script.Parent.Parent.Parent.Infrastructure.MachineUIAtom)
local useMachineOverlayPolling = require(script.Parent.useMachineOverlayPolling)
local useMachineOverlayAnimations = require(script.Parent.Animations.useMachineOverlayAnimations)
local useMachineOverlayActionItems = require(script.Parent.useMachineOverlayActionItems)
local MachineOverlayViewModel = require(script.Parent.Parent.ViewModels.MachineOverlayViewModel)
local MachineOverlayDefinitionResolver = require(script.Parent.Parent.Definitions.MachineOverlayDefinitionResolver)

local useAtom = ReactCharm.useAtom
local useCallback = React.useCallback
local useEffect = React.useEffect
local useMemo = React.useMemo
local useState = React.useState

type TActionVariant = "primary" | "secondary" | "ghost" | "danger"

export type TQueueRow = MachineOverlayViewModel.TQueueRow
export type TOutputEntry = MachineOverlayViewModel.TOutputEntry

export type TActionItem = {
	key: string,
	layoutOrder: number,
	text: string,
	variant: TActionVariant,
	onActivated: () -> (),
}

--[=[
	@type TMachineOverlayController
	@within useMachineOverlayController
	.isOpen boolean -- Whether the overlay is visible
	.zoneName string? -- Current zone name
	.slotIndex number? -- Current slot index
	.panelRef { current: Frame? } -- Ref for main panel animation
	.popupPanelRef { current: Frame? } -- Ref for action popup animation
	.outputPopupPanelRef { current: Frame? } -- Ref for output popup animation
	.titleText string -- Machine type display name
	.subtitleText string -- Location display (Zone — Slot N)
	.fuelSeconds number -- Remaining fuel time
	.fuelRatio number -- Fuel burn progress (0-1)
	.queueRows { TQueueRow } -- Queued recipes for display
	.outputEntries { TOutputEntry } -- Available outputs for display
	.isActionMenuOpen boolean -- Whether action menu is open
	.isOutputMenuOpen boolean -- Whether output menu is open
	.actionMenuButtonText string -- "Open Action Menu" or "Action Menu Open"
	.outputButtonText string -- "View Outputs" or "View Outputs (None)"
	.statusTitleText string -- "Status" label
	.statusMetricLabelText string -- "Fuel Remaining" label
	.queueTitleText string -- "Queue" label
	.queueEmptyText string -- No recipes queued message
	.actionsTitleText string -- "Actions" label
	.actionPopupTitleText string -- "Select Action" label
	.outputPopupTitleText string -- "Machine Outputs" label
	.outputPopupEmptyText string -- No outputs message
	.actionItems { TActionItem } -- Available actions with state
	.actionErrorFlashKey string -- Action key currently showing error
	.actionErrorFlashGeneration number -- Counter for error animation re-runs
	.onCloseOverlay () -> () -- Closes the overlay
	.onToggleActionMenu () -> () -- Toggles action menu open/closed
	.onOpenOutputMenu () -> () -- Opens output menu
	.onCloseActionMenu () -> () -- Closes action menu
	.onCloseOutputMenu () -> () -- Closes output menu
]=]
export type TMachineOverlayController = {
	isOpen: boolean,
	zoneName: string?,
	slotIndex: number?,
	panelRef: { current: Frame? },
	popupPanelRef: { current: Frame? },
	outputPopupPanelRef: { current: Frame? },
	titleText: string,
	subtitleText: string,
	fuelSeconds: number,
	fuelRatio: number,
	queueRows: { TQueueRow },
	outputEntries: { TOutputEntry },
	isActionMenuOpen: boolean,
	isOutputMenuOpen: boolean,
	actionMenuButtonText: string,
	outputButtonText: string,
	statusTitleText: string,
	statusMetricLabelText: string,
	queueTitleText: string,
	queueEmptyText: string,
	actionsTitleText: string,
	actionPopupTitleText: string,
	outputPopupTitleText: string,
	outputPopupEmptyText: string,
	actionItems: { TActionItem },
	actionErrorFlashKey: string,
	actionErrorFlashGeneration: number,
	onCloseOverlay: () -> (),
	onToggleActionMenu: () -> (),
	onOpenOutputMenu: () -> (),
	onCloseActionMenu: () -> (),
	onCloseOutputMenu: () -> (),
}

--[=[
	Orchestrates all machine overlay state, polling, animation, and action management.
	@within useMachineOverlayController
	@return TMachineOverlayController -- Complete overlay state and callbacks
	@yields
]=]
local function useMachineOverlayController(): TMachineOverlayController
	local ui = useAtom(MachineUIAtom.Atom)
	local isActionMenuOpen, setIsActionMenuOpen = useState(false)
	local isOutputMenuOpen, setIsOutputMenuOpen = useState(false)
	local buildingContext = Knit.GetService("BuildingContext")

	local isOpen = ui.open and ui.zoneName ~= nil and ui.slotIndex ~= nil
	local zoneName = ui.zoneName
	local slotIndex = ui.slotIndex

	local machineView = useMachineOverlayPolling(ui, buildingContext)
	local definition = useMemo(function()
		return MachineOverlayDefinitionResolver.resolve(machineView)
	end, { machineView })

	useEffect(function()
		if isOpen then
			return
		end
		setIsActionMenuOpen(false)
		setIsOutputMenuOpen(false)
	end, { isOpen } :: { any })

	local derived = useMemo(function()
		return MachineOverlayViewModel.fromMachineState(machineView, zoneName, slotIndex, definition)
	end, { machineView, zoneName, slotIndex, definition })

	local animationRefs = useMachineOverlayAnimations(isOpen, isActionMenuOpen, isOutputMenuOpen)

	local onCloseActionMenu = useCallback(function()
		setIsActionMenuOpen(false)
	end, {})

	local onCloseOutputMenu = useCallback(function()
		setIsOutputMenuOpen(false)
	end, {})

	local onCloseOverlay = useCallback(function()
		MachineUIAtom.Close()
	end, {})

	local onToggleActionMenu = useCallback(function()
		setIsOutputMenuOpen(false)
		setIsActionMenuOpen(function(previous)
			return not previous
		end)
	end, {})

	local onOpenOutputMenu = useCallback(function()
		setIsOutputMenuOpen(true)
		setIsActionMenuOpen(false)
	end, {})

	local actionMenu = useMachineOverlayActionItems({
		buildingContext = buildingContext,
		zoneName = zoneName,
		slotIndex = slotIndex,
		actionDefinitions = definition.actionDefinitions,
		actionCapabilities = derived.actionCapabilities,
		fuelLabel = derived.fuelLabel,
	})

	return {
		isOpen = isOpen,
		zoneName = zoneName,
		slotIndex = slotIndex,
		panelRef = animationRefs.panelRef,
		popupPanelRef = animationRefs.popupPanelRef,
		outputPopupPanelRef = animationRefs.outputPopupPanelRef,
		titleText = derived.titleText,
		subtitleText = derived.subtitleText,
		fuelSeconds = derived.fuelSeconds,
		fuelRatio = derived.fuelRatio,
		queueRows = derived.queueRows,
		outputEntries = derived.outputEntries,
		isActionMenuOpen = isActionMenuOpen,
		isOutputMenuOpen = isOutputMenuOpen,
		actionMenuButtonText = if isActionMenuOpen then derived.actionMenuOpenText else derived.openActionMenuText,
		outputButtonText = if #derived.outputEntries > 0 then derived.outputButtonText else derived.outputButtonEmptyText,
		statusTitleText = derived.statusTitleText,
		statusMetricLabelText = derived.statusMetricLabelText,
		queueTitleText = derived.queueTitleText,
		queueEmptyText = derived.queueEmptyText,
		actionsTitleText = derived.actionsTitleText,
		actionPopupTitleText = derived.actionPopupTitleText,
		outputPopupTitleText = derived.outputPopupTitleText,
		outputPopupEmptyText = derived.outputPopupEmptyText,
		actionItems = actionMenu.actionItems,
		actionErrorFlashKey = actionMenu.errorActionKey,
		actionErrorFlashGeneration = actionMenu.errorFlashGeneration,
		onCloseOverlay = onCloseOverlay,
		onToggleActionMenu = onToggleActionMenu,
		onOpenOutputMenu = onOpenOutputMenu,
		onCloseActionMenu = onCloseActionMenu,
		onCloseOutputMenu = onCloseOutputMenu,
	}
end

return useMachineOverlayController
