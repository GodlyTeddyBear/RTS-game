--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)
local e = React.createElement

local Frame = require(script.Parent.Parent.Parent.Parent.App.Presentation.Atoms.Frame)
local ScreenHeader = require(script.Parent.Parent.Parent.Parent.App.Presentation.Organisms.ScreenHeader)
local GradientTokens = require(script.Parent.Parent.Parent.Parent.App.Config.GradientTokens)
local GuildFooter = require(script.Parent.Parent.Organisms.GuildFooter)
local AdventurerEquipmentPanel = require(script.Parent.Parent.Organisms.AdventurerEquipmentPanel)
local AdventurerItemPickerPanel = require(script.Parent.Parent.Organisms.AdventurerItemPickerPanel)
local AdventurerEquipUiTokens = require(script.Parent.Parent.Parent.Config.AdventurerEquipUiTokens)
local EquipmentUiTypes = require(script.Parent.Parent.Parent.Types.EquipmentUiTypes)

type TAdventurerDetailScreenViewProps = {
	containerRef: any,
	adventurerTypeLabel: string,
	layoutViewModel: EquipmentUiTypes.TAdventurerEquipmentLayoutViewModel,
	onBack: () -> (),
	onSelectSlot: (slotId: EquipmentUiTypes.TEquipUiSlotId, backendSlotType: string?, isFuture: boolean) -> (),
	onUnequipSlot: (backendSlotType: string?) -> (),
	onSelectPickerItem: (slotIndex: number) -> (),
}

local function AdventurerDetailScreenView(props: TAdventurerDetailScreenViewProps)
	return e("Frame", {
		ref = props.containerRef,
		Visible = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(30, 30, 35),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		Header = e(ScreenHeader, {
			Title = props.adventurerTypeLabel,
			Position = UDim2.fromScale(0.5, 0.049),
			OnBack = props.onBack,
		}),
		Content = e(Frame, {
			Position = AdventurerEquipUiTokens.ROOT_PANEL_POSITION,
			Size = AdventurerEquipUiTokens.ROOT_PANEL_SIZE,
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0,
			Gradient = GradientTokens.LIST_CONTAINER_GRADIENT,
			GradientRotation = -16,
			StrokeColor = GradientTokens.GOLD_STROKE,
			StrokeThickness = 4,
			StrokeMode = Enum.ApplyStrokeMode.Border,
			ClipsDescendants = true,
			children = {
				LoadoutContainer = e(AdventurerEquipmentPanel, {
					slotTiles = props.layoutViewModel.SlotTiles,
					statRows = props.layoutViewModel.StatRows,
					onSelectSlot = props.onSelectSlot,
					onUnequipSlot = props.onUnequipSlot,
				}),
				ItemContainer = e(AdventurerItemPickerPanel, {
					selectedSlotLabel = props.layoutViewModel.SelectedSlotLabel,
					items = props.layoutViewModel.ItemTiles,
					onSelectItem = props.onSelectPickerItem,
				}),
			},
		}),
		Footer = e(GuildFooter, {
			Position = UDim2.fromScale(0.5, 0.95948),
		}),
	})
end

return AdventurerDetailScreenView
