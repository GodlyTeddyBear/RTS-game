--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local EquipmentSlotTile = require(script.Parent.Parent.Molecules.EquipmentSlotTile)
local EquipmentStatRow = require(script.Parent.Parent.Molecules.EquipmentStatRow)
local AdventurerEquipUiTokens = require(script.Parent.Parent.Parent.Config.AdventurerEquipUiTokens)
local EquipmentUiTypes = require(script.Parent.Parent.Parent.Types.EquipmentUiTypes)

type TEquipSlotTileViewData = EquipmentUiTypes.TEquipSlotTileViewData
type TEquipStatRowViewData = EquipmentUiTypes.TEquipStatRowViewData

export type TAdventurerEquipmentPanelProps = {
	slotTiles: { TEquipSlotTileViewData },
	statRows: { TEquipStatRowViewData },
	onSelectSlot: (slotId: EquipmentUiTypes.TEquipUiSlotId, backendSlotType: string?, isFuture: boolean) -> (),
	onUnequipSlot: (backendSlotType: string?) -> (),
}

local function _buildColumnTiles(
	slotTiles: { TEquipSlotTileViewData },
	startIndex: number,
	endIndex: number,
	onSelectSlot: (slotId: EquipmentUiTypes.TEquipUiSlotId, backendSlotType: string?, isFuture: boolean) -> (),
	onUnequipSlot: (backendSlotType: string?) -> ()
): { [string]: any }
	local children: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i = startIndex, endIndex do
		local tile = slotTiles[i]
		if tile ~= nil then
			children[tile.SlotId] = e(EquipmentSlotTile, {
				Label = tile.Label,
				ItemName = if tile.Equipment ~= nil then tile.Equipment.ItemName else "Empty",
				BackendSlotType = tile.BackendSlotType,
				IsFuture = tile.IsFuture,
				IsSelected = tile.IsSelected,
				LayoutOrder = i,
				OnSelect = function()
					onSelectSlot(tile.SlotId, tile.BackendSlotType, tile.IsFuture)
				end,
				OnUnequip = onUnequipSlot,
			})
		end
	end

	return children
end

local function AdventurerEquipmentPanel(props: TAdventurerEquipmentPanelProps)
	local statChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	for i, statRow in ipairs(props.statRows) do
		statChildren["Stat_" .. statRow.Label] = e(EquipmentStatRow, {
			Label = statRow.Label,
			Value = statRow.Value,
			LayoutOrder = i,
		})
	end

	return e(Frame, {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = AdventurerEquipUiTokens.LEFT_PANEL_POSITION,
		Size = AdventurerEquipUiTokens.LEFT_PANEL_SIZE,
		Gradient = GradientTokens.PANEL_GRADIENT,
		GradientRotation = -140.856,
		StrokeColor = GradientTokens.GOLD_STROKE_SUBTLE,
		StrokeThickness = 4,
		ClipsDescendants = true,
	}, {
		ArrayOne = e("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.05444, 0.5),
			Size = UDim2.fromScale(0.33266, 0.93565),
		}, _buildColumnTiles(props.slotTiles, 1, 4, props.onSelectSlot, props.onUnequipSlot)),
		ArrayTwo = e("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.94556, 0.5),
			Size = UDim2.fromScale(0.33266, 0.93565),
		}, _buildColumnTiles(props.slotTiles, 5, 8, props.onSelectSlot, props.onUnequipSlot)),
		CenterSpacer = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.48038),
			Size = AdventurerEquipUiTokens.CENTER_GAP_SIZE,
		}),
		Stats = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.18668),
			Size = UDim2.fromScale(0.19167, 0.12),
		}, statChildren),
	})
end

return AdventurerEquipmentPanel
