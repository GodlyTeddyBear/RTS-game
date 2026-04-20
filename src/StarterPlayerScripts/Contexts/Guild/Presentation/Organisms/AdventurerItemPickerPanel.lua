--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local EquippableItemTile = require(script.Parent.Parent.Molecules.EquippableItemTile)
local AdventurerEquipUiTokens = require(script.Parent.Parent.Parent.Config.AdventurerEquipUiTokens)
local EquipmentUiTypes = require(script.Parent.Parent.Parent.Types.EquipmentUiTypes)

type TEquippableItemTileViewData = EquipmentUiTypes.TEquippableItemTileViewData

export type TAdventurerItemPickerPanelProps = {
	selectedSlotLabel: string,
	items: { TEquippableItemTileViewData },
	onSelectItem: (slotIndex: number) -> (),
}

local function AdventurerItemPickerPanel(props: TAdventurerItemPickerPanelProps)
	local scrollChildren: { [string]: any } = {
		UIListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = if #props.items == 0
				then Enum.VerticalAlignment.Center
				else Enum.VerticalAlignment.Top,
			Padding = UDim.new(0.02, 0),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		UIPadding = e("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
			PaddingTop = UDim.new(0.015, 0),
			PaddingBottom = UDim.new(0.015, 0),
		}),
	}

	if #props.items == 0 then
		scrollChildren.Empty = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json"),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.9, 0.2),
			Text = "No equippable items for " .. props.selectedSlotLabel,
			TextColor3 = Color3.fromRGB(178, 178, 178),
			TextSize = 20,
			TextWrapped = true,
		})
	else
		for i, item in ipairs(props.items) do
			scrollChildren["Item_" .. tostring(item.SlotIndex)] = e(EquippableItemTile, {
				Name = item.Name,
				StatsText = item.StatsText,
				Quantity = item.Quantity,
				LayoutOrder = i,
				OnSelect = function()
					props.onSelectItem(item.SlotIndex)
				end,
			})
		end
	end

	return e(Frame, {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = AdventurerEquipUiTokens.RIGHT_PANEL_POSITION,
		Size = AdventurerEquipUiTokens.RIGHT_PANEL_SIZE,
		Gradient = GradientTokens.PANEL_GRADIENT,
		GradientRotation = -140.856,
		StrokeColor = GradientTokens.GOLD_STROKE_SUBTLE,
		StrokeThickness = 4,
		ClipsDescendants = true,
	}, {
		Title = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.05),
			Size = UDim2.fromScale(0.9, 0.08),
			FontFace = Font.new("rbxasset://fonts/families/GothicA1.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
			Text = props.selectedSlotLabel .. " Items",
			TextColor3 = Color3.new(1, 1, 1),
			TextSize = 26,
			TextWrapped = true,
		}, {
			UIStroke = e("UIStroke", {
				Color = Color3.fromRGB(4, 4, 4),
				Thickness = 4.5,
			}),
		}),
		ItemContainerScroll = e("ScrollingFrame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			CanvasSize = UDim2.new(),
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.fromScale(0.87302, 0.80),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = GradientTokens.GOLD_SCROLLBAR_COLOR,
		}, scrollChildren),
	})
end

return AdventurerItemPickerPanel
