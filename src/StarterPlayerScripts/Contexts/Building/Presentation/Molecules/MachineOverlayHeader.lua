--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local e = React.createElement

local PANEL_HEADER = Colors.NPC.PanelHeaderDark
local PANEL_SUBTLE = Colors.NPC.PanelSubtle

export type TMachineOverlayHeaderProps = {
	titleText: string,
	subtitleText: string,
	onCloseOverlay: () -> (),
}

local function MachineOverlayHeader(props: TMachineOverlayHeaderProps)
	return e("Frame", {
		Size = UDim2.fromScale(1, 0.12),
		BackgroundColor3 = PANEL_HEADER,
		BorderSizePixel = 0,
		ZIndex = 42,
	}, {
		HeaderCorner = e("UICorner", { CornerRadius = UDim.new(0.035, 0) }),
		HeaderPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.02, 0),
		}),
		Title = e(Text, {
			Text = props.titleText,
			Variant = "heading",
			TextScaled = true,
			Size = UDim2.fromScale(0.7, 1),
			TextColor3 = Colors.NPC.ScoutGold,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		Subtitle = e(Text, {
			Text = props.subtitleText,
			Variant = "caption",
			TextScaled = true,
			Size = UDim2.fromScale(0.25, 1),
			Position = UDim2.fromScale(0.5, 0),
			TextColor3 = PANEL_SUBTLE,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		CloseButton = e(Button, {
			Size = UDim2.fromScale(0.06, 0.5),
			Position = UDim2.fromScale(0.99, 0.5),
			AnchorPoint = Vector2.new(1, 0.5),
			Text = "X",
			TextScaled = true,
			Variant = "ghost",
			[React.Event.Activated] = props.onCloseOverlay,
		}),
	})
end

return MachineOverlayHeader
