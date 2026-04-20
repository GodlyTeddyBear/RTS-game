--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local MachineActionPopupView = require(script.Parent.MachineActionPopupView)
local MachineOutputPopupView = require(script.Parent.MachineOutputPopupView)
local MachineOverlayHeader = require(script.Parent.Parent.Molecules.MachineOverlayHeader)
local MachineStatusCard = require(script.Parent.Parent.Molecules.MachineStatusCard)
local MachineQueueList = require(script.Parent.Parent.Molecules.MachineQueueList)
local MachineOverlayActionsRow = require(script.Parent.Parent.Molecules.MachineOverlayActionsRow)

local e = React.createElement

local PANEL_BACKGROUND = Colors.NPC.PanelBackground
local PANEL_BORDER = Colors.NPC.PanelBorder
local PANEL_SUBTLE = Colors.NPC.PanelSubtle
local OVERLAY_BACKDROP = Colors.NPC.PanelBackdrop

type TActionVariant = "primary" | "secondary" | "ghost" | "danger"

type TQueueRow = {
	key: string,
	index: number,
	name: string,
	progressLabel: string,
}

type TOutputEntry = {
	key: string,
	label: string,
	source: string,
}

type TActionItem = {
	key: string,
	layoutOrder: number,
	text: string,
	variant: TActionVariant,
	onActivated: () -> (),
}

export type TMachineOverlayViewProps = {
	isOpen: boolean,
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

local function _sectionTitle(text: string, layoutOrder: number)
	return e(Text, {
		Text = text,
		Variant = "label",
		TextScaled = true,
		LayoutOrder = layoutOrder,
		TextColor3 = PANEL_SUBTLE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, 0.05),
	})
end

local function _body(props: TMachineOverlayViewProps)
	return e("Frame", {
		Position = UDim2.fromScale(0, 0.12),
		Size = UDim2.fromScale(1, 0.88),
		BackgroundTransparency = 1,
		ZIndex = 42,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Pad = e("UIPadding", {
			PaddingTop = UDim.new(0.02, 0),
			PaddingBottom = UDim.new(0.025, 0),
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
		}),
		StatusTitle = _sectionTitle(props.statusTitleText, 1),
		StatusCard = e(MachineStatusCard, {
			layoutOrder = 2,
			metricLabelText = props.statusMetricLabelText,
			fuelSeconds = props.fuelSeconds,
			fuelRatio = props.fuelRatio,
		}),
		QueueTitle = _sectionTitle(props.queueTitleText, 3),
		QueueCard = e(MachineQueueList, {
			layoutOrder = 4,
			queueRows = props.queueRows,
			queueEmptyText = props.queueEmptyText,
		}),
		ActionsTitle = _sectionTitle(props.actionsTitleText, 5),
		ActionsRow = e(MachineOverlayActionsRow, {
			layoutOrder = 6,
			actionMenuButtonText = props.actionMenuButtonText,
			outputButtonText = props.outputButtonText,
			onToggleActionMenu = props.onToggleActionMenu,
			onOpenOutputMenu = props.onOpenOutputMenu,
		}),
	})
end

local function _panel(props: TMachineOverlayViewProps)
	return e("Frame", {
		ref = props.panelRef,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = PANEL_BACKGROUND,
		Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.46, 0.66),
		ZIndex = 41,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.035, 0) }),
		Stroke = e("UIStroke", {
			Color = PANEL_BORDER,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Header = e(MachineOverlayHeader, {
			titleText = props.titleText,
			subtitleText = props.subtitleText,
			onCloseOverlay = props.onCloseOverlay,
		}),
		Body = _body(props),
	})
end

local function MachineOverlayView(props: TMachineOverlayViewProps)
	if not props.isOpen then
		return nil
	end

	return e("Frame", {
		Name = "MachineOverlay",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = OVERLAY_BACKDROP,
		BackgroundTransparency = 0.35,
		ZIndex = 40,
	}, {
		Panel = _panel(props),
		ActionPopup = e(MachineActionPopupView, {
			visible = props.isActionMenuOpen,
			popupPanelRef = props.popupPanelRef,
			titleText = props.actionPopupTitleText,
			actionItems = props.actionItems,
			errorFlashKey = props.actionErrorFlashKey,
			errorFlashGeneration = props.actionErrorFlashGeneration,
			onClose = props.onCloseActionMenu,
		}),
		OutputPopup = e(MachineOutputPopupView, {
			visible = props.isOutputMenuOpen,
			popupPanelRef = props.outputPopupPanelRef,
			titleText = props.outputPopupTitleText,
			emptyText = props.outputPopupEmptyText,
			outputEntries = props.outputEntries,
			onClose = props.onCloseOutputMenu,
		}),
	})
end

return MachineOverlayView
