--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local e = React.createElement

local PANEL_BACKGROUND = Colors.NPC.PanelBackground
local PANEL_HEADER = Colors.NPC.PanelHeaderDark
local PANEL_BORDER = Colors.NPC.PanelBorder
local PANEL_SUBTLE = Colors.NPC.PanelSubtle

--[=[
	@type TMachinePopupShellProps
	@within MachinePopupShell
	.panelRef { current: Frame? } -- Panel reference for animation
	.titleText string -- Popup heading text
	.panelSize UDim2 -- Size of the popup panel
	.listChildren { [string]: any } -- Children for the scrolling list area
	.onClose () -> () -- Backdrop click callback
]=]
export type TMachinePopupShellProps = {
	panelRef: { current: Frame? },
	titleText: string,
	panelSize: UDim2,
	listChildren: { [string]: any },
	onClose: () -> (),
}

--[=[
	@class MachinePopupShell
	Shared popup shell used by MachineActionPopupView and MachineOutputPopupView.
	Renders backdrop, panel frame, header title, and a scrolling list area.
	@client
]=]
local function MachinePopupShell(props: TMachinePopupShellProps)
	return e("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		ZIndex = 45,
	}, {
		Backdrop = e("TextButton", {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Text = "",
			ZIndex = 45,
			[React.Event.Activated] = props.onClose,
		}),
		PopupPanel = e("Frame", {
			ref = props.panelRef,
			Size = props.panelSize,
			Position = UDim2.fromScale(0.5, 0.54),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = PANEL_BACKGROUND,
			BorderSizePixel = 0,
			ZIndex = 46,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.05, 0) }),
			Stroke = e("UIStroke", {
				Color = PANEL_BORDER,
				Thickness = 1,
			}),
			Header = e("Frame", {
				Size = UDim2.fromScale(1, 0.2),
				BackgroundColor3 = PANEL_HEADER,
				BorderSizePixel = 0,
				ZIndex = 47,
			}, {
				HeaderCorner = e("UICorner", { CornerRadius = UDim.new(0.05, 0) }),
				Title = e(Text, {
					Text = props.titleText,
					Variant = "label",
					TextScaled = true,
					Size = UDim2.fromScale(1, 1),
					TextColor3 = Colors.NPC.ScoutGold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			}),
			ContentList = e("ScrollingFrame", {
				Size = UDim2.fromScale(0.92, 0.72),
				Position = UDim2.fromScale(0.5, 0.58),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromScale(0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarImageColor3 = PANEL_SUBTLE,
				ScrollBarThickness = 6,
				ZIndex = 47,
			}, props.listChildren),
		}),
	})
end

return MachinePopupShell
