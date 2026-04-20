--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)

local MachineInfoRow = require(script.Parent.MachineInfoRow)

local e = React.createElement

local PANEL_MUTED = Colors.NPC.PanelMuted
local PANEL_HEADER = Colors.NPC.PanelHeaderDark

export type TQueueRow = {
	key: string,
	index: number,
	name: string,
	progressLabel: string,
}

export type TMachineQueueListProps = {
	layoutOrder: number,
	queueRows: { TQueueRow },
	queueEmptyText: string,
}

local function _buildQueueChildren(queueRows: { TQueueRow }, queueEmptyText: string): { [string]: any }
	local queueChildren: { [string]: any } = {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0.06, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	if #queueRows == 0 then
		queueChildren.Empty = e(Text, {
			Text = queueEmptyText,
			Variant = "caption",
			TextScaled = true,
			LayoutOrder = 1,
			Size = UDim2.fromScale(1, 0.22),
			TextColor3 = PANEL_MUTED,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		})
	else
		for _, row in ipairs(queueRows) do
			queueChildren[row.key] = e(MachineInfoRow, {
				layoutOrder = row.index,
				leftText = row.name,
				rightText = row.progressLabel,
				leftVariant = "body",
				rightVariant = "caption",
			})
		end
	end

	return queueChildren
end

local function MachineQueueList(props: TMachineQueueListProps)
	local queueChildren = _buildQueueChildren(props.queueRows, props.queueEmptyText)

	return e("Frame", {
		LayoutOrder = props.layoutOrder,
		Size = UDim2.fromScale(1, 0.24),
		BackgroundColor3 = PANEL_HEADER,
		BorderSizePixel = 0,
	}, {
		Corner = e("UICorner", { CornerRadius = UDim.new(0.06, 0) }),
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0.08, 0),
			PaddingBottom = UDim.new(0.08, 0),
			PaddingLeft = UDim.new(0.03, 0),
			PaddingRight = UDim.new(0.03, 0),
		}),
		List = e("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, queueChildren),
	})
end

return MachineQueueList
