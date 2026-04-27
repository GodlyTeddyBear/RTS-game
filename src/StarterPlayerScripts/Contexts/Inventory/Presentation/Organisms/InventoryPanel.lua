--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local AppFrame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local Button = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Button)
local IconButton = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.IconButton)
local Text = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Text)
local Colors = require(script.Parent.Parent.Parent.Parent.App.Config.ColorTokens)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)

type TInventoryResourceRow = {
	Name: string,
	AmountText: string,
	IsSyncing: boolean,
	LayoutOrder: number,
}

type TInventorySlotRow = {
	SlotIndex: number,
	Name: string,
	QuantityText: string,
	Rarity: string,
	Category: string,
	LayoutOrder: number,
}

type TInventoryViewData = {
	Title: string,
	CapacityText: string,
	IsResourceSyncing: boolean,
	IsInventoryEmpty: boolean,
	ResourceRows: { TInventoryResourceRow },
	SlotRows: { TInventorySlotRow },
	OverflowText: string?,
}

export type TInventoryPanelProps = {
	viewModel: TInventoryViewData,
	onClose: () -> (),
}

local RESOURCE_WIDTH = 0.22
local SLOT_COLUMNS = 5
local SLOT_WIDTH = 0.18
local SLOT_HEIGHT = 0.27
local SLOT_START_X = 0.11
local SLOT_START_Y = 0.18
local SLOT_GAP_X = 0.195
local SLOT_GAP_Y = 0.31

local RARITY_COLORS = table.freeze({
	Common = Colors.Rarity.Common,
	Uncommon = Colors.Rarity.Uncommon,
	Rare = Colors.Rarity.Rare,
	Epic = Colors.Rarity.Epic,
	Legendary = Colors.Rarity.Legendary,
})

local function _GetRarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or Colors.Rarity.Common
end

local function _CreateResourceRow(row: TInventoryResourceRow)
	local xPosition = 0.5 + ((row.LayoutOrder - 2.5) * RESOURCE_WIDTH)

	return e(AppFrame, {
		Size = UDim2.fromScale(0.2, 0.72),
		Position = UDim2.fromScale(xPosition, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Colors.Surface.Secondary,
		BackgroundTransparency = 0.16,
		CornerRadius = UDim.new(0, 8),
		StrokeColor = GradientTokens.SLOT_DECORE_STROKE,
		StrokeThickness = 1,
		LayoutOrder = row.LayoutOrder,
	}, {
		Name = e(Text, {
			Size = UDim2.fromScale(0.9, 0.34),
			Position = UDim2.fromScale(0.5, 0.26),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = row.Name,
			Variant = "caption",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		Amount = e(Text, {
			Size = UDim2.fromScale(0.9, 0.42),
			Position = UDim2.fromScale(0.5, 0.66),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = row.AmountText,
			Variant = "body",
			TextColor3 = if row.IsSyncing then Colors.Text.Muted else Colors.Accent.Yellow,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextScaled = true,
		}),
	})
end

local function _CreateSlot(row: TInventorySlotRow, index: number)
	local zeroBased = index - 1
	local column = zeroBased % SLOT_COLUMNS
	local rowIndex = math.floor(zeroBased / SLOT_COLUMNS)
	local rarityColor = _GetRarityColor(row.Rarity)

	return e(AppFrame, {
		Size = UDim2.fromScale(SLOT_WIDTH, SLOT_HEIGHT),
		Position = UDim2.fromScale(SLOT_START_X + (column * SLOT_GAP_X), SLOT_START_Y + (rowIndex * SLOT_GAP_Y)),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Colors.Surface.Secondary,
		BackgroundTransparency = 0.08,
		CornerRadius = UDim.new(0, 8),
		StrokeColor = GradientTokens.SLOT_DECORE_STROKE,
		StrokeThickness = 1,
		LayoutOrder = row.LayoutOrder,
	}, {
		RarityStrip = e(AppFrame, {
			Size = UDim2.fromScale(0.92, 0.08),
			Position = UDim2.fromScale(0.5, 0.12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = rarityColor,
			BackgroundTransparency = 0,
			CornerRadius = UDim.new(0, 4),
		}),
		Name = e(Text, {
			Size = UDim2.fromScale(0.84, 0.3),
			Position = UDim2.fromScale(0.5, 0.38),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = row.Name,
			Variant = "caption",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = true,
		}),
		Quantity = e(Text, {
			Size = UDim2.fromScale(0.84, 0.22),
			Position = UDim2.fromScale(0.5, 0.66),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = row.QuantityText,
			Variant = "body",
			TextColor3 = Colors.Accent.Yellow,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
		Category = e(Text, {
			Size = UDim2.fromScale(0.84, 0.16),
			Position = UDim2.fromScale(0.5, 0.86),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Text = row.Category,
			Variant = "caption",
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

local function _CreateResourceRows(rows: { TInventoryResourceRow })
	local children = {}
	for _, row in rows do
		children[row.Name] = _CreateResourceRow(row)
	end
	return children
end

local function _CreateSlotRows(rows: { TInventorySlotRow })
	local children = {}
	for index, row in rows do
		children["Slot" .. tostring(row.SlotIndex)] = _CreateSlot(row, index)
	end
	return children
end

local function InventoryPanel(props: TInventoryPanelProps)
	local resourceChildren = _CreateResourceRows(props.viewModel.ResourceRows)
	local slotChildren = _CreateSlotRows(props.viewModel.SlotRows)

	return e(AppFrame, {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.42,
		ZIndex = 20,
	}, {
		Panel = e(AppFrame, {
			Size = UDim2.fromScale(0.54, 0.62),
			Position = UDim2.fromScale(0.5, 0.48),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Colors.NPC.PanelBackground,
			BackgroundTransparency = 0.04,
			Gradient = GradientTokens.PANEL_GRADIENT,
			GradientRotation = 90,
			CornerRadius = UDim.new(0, 12),
			StrokeColor = GradientTokens.GOLD_STROKE_SUBTLE,
			StrokeThickness = 2,
			ZIndex = 21,
		}, {
			Title = e(Text, {
				Size = UDim2.fromScale(0.56, 0.1),
				Position = UDim2.fromScale(0.5, 0.08),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = props.viewModel.Title,
				Variant = "heading",
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Close = e(IconButton, {
				Icon = "close",
				Size = UDim2.fromScale(0.075, 0.075),
				Position = UDim2.fromScale(0.94, 0.08),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Variant = "ghost",
				[React.Event.Activated] = props.onClose,
			}),
			Capacity = e(Text, {
				Size = UDim2.fromScale(0.28, 0.07),
				Position = UDim2.fromScale(0.17, 0.09),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = props.viewModel.CapacityText,
				Variant = "caption",
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Resources = e(AppFrame, {
				Size = UDim2.fromScale(0.9, 0.14),
				Position = UDim2.fromScale(0.5, 0.2),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Colors.Surface.Primary,
				BackgroundTransparency = 0.18,
				CornerRadius = UDim.new(0, 10),
				StrokeColor = GradientTokens.SLOT_DECORE_STROKE,
				StrokeThickness = 1,
			}, resourceChildren),
			ItemsLabel = e(Text, {
				Size = UDim2.fromScale(0.9, 0.06),
				Position = UDim2.fromScale(0.5, 0.31),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = "Items",
				Variant = "label",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
			Items = e(AppFrame, {
				Size = UDim2.fromScale(0.9, 0.52),
				Position = UDim2.fromScale(0.5, 0.61),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Colors.Surface.Primary,
				BackgroundTransparency = 0.24,
				CornerRadius = UDim.new(0, 10),
				StrokeColor = GradientTokens.SLOT_DECORE_STROKE,
				StrokeThickness = 1,
			}, if props.viewModel.IsInventoryEmpty then {
				Empty = e(Text, {
					Size = UDim2.fromScale(0.9, 0.16),
					Position = UDim2.fromScale(0.5, 0.5),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Text = "No items stored yet.",
					Variant = "body",
					TextColor3 = Colors.Text.Muted,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
				}),
			} else slotChildren),
			Overflow = props.viewModel.OverflowText and e(Button, {
				Size = UDim2.fromScale(0.2, 0.07),
				Position = UDim2.fromScale(0.5, 0.93),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Text = props.viewModel.OverflowText,
				Variant = "ghost",
				DisableAnimations = true,
			}) or nil,
		}),
	})
end

return InventoryPanel
