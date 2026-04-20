--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)

local e = React.createElement

export type TMachineOverlayActionsRowProps = {
	layoutOrder: number,
	actionMenuButtonText: string,
	outputButtonText: string,
	onToggleActionMenu: () -> (),
	onOpenOutputMenu: () -> (),
}

local function MachineOverlayActionsRow(props: TMachineOverlayActionsRowProps)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0.12),
		BackgroundTransparency = 1,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		OpenActions = e(Button, {
			LayoutOrder = 1,
			Size = UDim2.fromScale(0.47, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = props.actionMenuButtonText,
			TextScaled = true,
			Variant = "primary",
			[React.Event.Activated] = props.onToggleActionMenu,
		}),
		ViewOutputs = e(Button, {
			LayoutOrder = 2,
			Size = UDim2.fromScale(0.47, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = props.outputButtonText,
			TextScaled = true,
			Variant = "secondary",
			[React.Event.Activated] = props.onOpenOutputMenu,
		}),
	})
end

return MachineOverlayActionsRow
