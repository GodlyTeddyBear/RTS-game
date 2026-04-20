--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)

local useMachineActionButtonController = require(script.Parent.Parent.Parent.Application.Hooks.Animations.useMachineActionButtonController)
local MachinePopupShell = require(script.Parent.Parent.Molecules.MachinePopupShell)

local e = React.createElement

type TActionVariant = "primary" | "secondary" | "ghost" | "danger"

type TActionItem = {
	key: string,
	layoutOrder: number,
	text: string,
	variant: TActionVariant,
	onActivated: () -> (),
}

--[=[
	@type TMachineActionPopupViewProps
	@within MachineActionPopupView
	.visible boolean -- Whether the popup is shown
	.popupPanelRef { current: Frame? } -- Panel reference for animation
	.titleText string -- Popup heading text
	.actionItems { TActionItem } -- Actions to display as buttons
	.errorFlashKey string -- Key of action currently showing error
	.errorFlashGeneration number -- Counter to trigger error animations
	.onClose () -> () -- Close button callback
]=]
export type TMachineActionPopupViewProps = {
	visible: boolean,
	popupPanelRef: { current: Frame? },
	titleText: string,
	actionItems: { TActionItem },
	errorFlashKey: string,
	errorFlashGeneration: number,
	onClose: () -> (),
}

--[=[
	@class MachineActionPopupView
	Renders a popup menu with action buttons and error flash animations.
	@client
]=]

local function MachineActionPopupActionButton(props: {
	layoutOrder: number,
	actionKey: string,
	text: string,
	variant: TActionVariant,
	onActivated: () -> (),
	errorFlashKey: string,
	errorFlashGeneration: number,
})
	local controller = useMachineActionButtonController(
		props.actionKey,
		props.errorFlashKey,
		props.errorFlashGeneration
	)

	return e("Frame", {
		ref = controller.wrapRef,
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0.2),
		BackgroundTransparency = 1,
	}, {
		Button = e(Button, {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = props.text,
			TextScaled = true,
			Variant = props.variant,
			[React.Event.Activated] = props.onActivated,
		}),
	})
end

local function MachineActionPopupView(props: TMachineActionPopupViewProps)
	if not props.visible then
		return nil
	end

	local actionListChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0.045, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}

	for _, action in ipairs(props.actionItems) do
		actionListChildren[action.key] = e(MachineActionPopupActionButton, {
			layoutOrder = action.layoutOrder,
			actionKey = action.key,
			text = action.text,
			variant = action.variant,
			onActivated = action.onActivated,
			errorFlashKey = props.errorFlashKey,
			errorFlashGeneration = props.errorFlashGeneration,
		})
	end

	return e(MachinePopupShell, {
		panelRef = props.popupPanelRef,
		titleText = props.titleText,
		panelSize = UDim2.fromScale(0.38, 0.5),
		listChildren = actionListChildren,
		onClose = props.onClose,
	})
end

return MachineActionPopupView
