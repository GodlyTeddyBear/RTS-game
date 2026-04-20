--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local MachinePopupShell = require(script.Parent.Parent.Molecules.MachinePopupShell)
local MachineInfoRow = require(script.Parent.Parent.Molecules.MachineInfoRow)

local e = React.createElement

local PANEL_MUTED = Colors.NPC.PanelMuted

type TOutputEntry = {
	key: string,
	label: string,
	source: string,
}

--[=[
	@type TMachineOutputPopupViewProps
	@within MachineOutputPopupView
	.visible boolean -- Whether the popup is shown
	.popupPanelRef { current: Frame? } -- Panel reference for animation
	.titleText string -- Popup heading text ("Machine Outputs")
	.emptyText string -- Message when no outputs available
	.outputEntries { TOutputEntry } -- Output items to display
	.onClose () -> () -- Close button callback
]=]
export type TMachineOutputPopupViewProps = {
	visible: boolean,
	popupPanelRef: { current: Frame? },
	titleText: string,
	emptyText: string,
	outputEntries: { TOutputEntry },
	onClose: () -> (),
}

--[=[
	@class MachineOutputPopupView
	Renders a popup menu displaying machine outputs (buffered and queued).
	@client
]=]

local function MachineOutputPopupView(props: TMachineOutputPopupViewProps)
	if not props.visible then
		return nil
	end

	local outputChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0.045, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	if #props.outputEntries == 0 then
		outputChildren.Empty = e(Text, {
			Text = props.emptyText,
			Variant = "caption",
			TextScaled = true,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.2),
			TextColor3 = PANEL_MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	else
		for index, entry in ipairs(props.outputEntries) do
			outputChildren[entry.key] = e(MachineInfoRow, {
				layoutOrder = index,
				leftText = entry.label,
				rightText = entry.source,
				leftVariant = "body",
				rightVariant = "caption",
				leftWidthScale = 0.64,
			})
		end
	end

	return e(MachinePopupShell, {
		panelRef = props.popupPanelRef,
		titleText = props.titleText,
		panelSize = UDim2.fromScale(0.4, 0.52),
		listChildren = outputChildren,
		onClose = props.onClose,
	})
end

return MachineOutputPopupView
