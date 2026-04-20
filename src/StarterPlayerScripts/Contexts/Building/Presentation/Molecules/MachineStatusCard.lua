--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local e = React.createElement

local PANEL_TEXT = Colors.NPC.PanelText
local PANEL_MUTED = Colors.NPC.PanelMuted
local PANEL_HEADER = Colors.NPC.PanelHeaderDark

export type TMachineStatusCardProps = {
	layoutOrder: number,
	metricLabelText: string,
	fuelSeconds: number,
	fuelRatio: number,
}

local function _formatSeconds(seconds: number): string
	if seconds <= 0 then
		return "0.0s"
	end
	return string.format("%.1fs", seconds)
end

local function _metricRow(label: string, value: string, layoutOrder: number)
	return e("Frame", {
		LayoutOrder = layoutOrder,
		Size = UDim2.fromScale(1, 0.3),
		BackgroundTransparency = 1,
	}, {
		Label = e(Text, {
			Text = label,
			Variant = "caption",
			TextScaled = true,
			Size = UDim2.fromScale(0.45, 1),
			TextColor3 = PANEL_MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		Value = e(Text, {
			Text = value,
			Variant = "body",
			TextScaled = true,
			Size = UDim2.fromScale(0.55, 1),
			Position = UDim2.fromScale(0.45, 0),
			TextColor3 = PANEL_TEXT,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

local function MachineStatusCard(props: TMachineStatusCardProps)
	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0.22),
		BackgroundColor3 = PANEL_HEADER,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.06, 0) }),
		CardPadding = e("UIPadding", {
			PaddingTop = UDim.new(0.08, 0),
			PaddingBottom = UDim.new(0.08, 0),
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
		}),
		CardLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0.06, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		FuelMetric = _metricRow(props.metricLabelText, _formatSeconds(props.fuelSeconds), 1),
		FuelBarBack = e("Frame", {
			LayoutOrder = 2,
			Size = UDim2.fromScale(1, 0.16),
			BackgroundColor3 = Colors.Surface.Primary,
			BorderSizePixel = 0,
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			FuelBarFill = e("Frame", {
				Size = UDim2.fromScale(props.fuelRatio, 1),
				BackgroundColor3 = if props.fuelRatio > 0 then Colors.Accent.Yellow else Colors.Border.Subtle,
				BorderSizePixel = 0,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
			}),
		}),
	})
end

return MachineStatusCard
