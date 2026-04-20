--!strict

local AdventurerViewModel = require(script.Parent.Parent.Application.ViewModels.AdventurerViewModel)
local EquippableItemViewModel = require(script.Parent.Parent.Application.ViewModels.EquippableItemViewModel)

export type TEquipUiSlotId =
	"Weapon" | "Helmet" | "Torso" | "Legs" | "Accessory1" | "Accessory2" | "Accessory3" | "Accessory4"

export type TEquipSlotTileViewData = {
	SlotId: TEquipUiSlotId,
	Label: string,
	BackendSlotType: string?,
	IsFuture: boolean,
	IsSelected: boolean,
	Equipment: AdventurerViewModel.TEquipmentSlotViewModel?,
}

export type TEquipStatRowViewData = {
	Label: string,
	Value: string,
}

export type TEquippableItemTileViewData = {
	SlotIndex: number,
	Name: string,
	StatsText: string,
	Quantity: number,
}

export type TAdventurerEquipmentLayoutViewModel = {
	SlotTiles: { TEquipSlotTileViewData },
	ItemTiles: { TEquippableItemTileViewData },
	StatRows: { TEquipStatRowViewData },
	SelectedSlotId: TEquipUiSlotId?,
	SelectedSlotLabel: string,
}

export type TBuildLayoutParams = {
	adventurerViewModel: AdventurerViewModel.TAdventurerViewModel,
	selectedSlotId: TEquipUiSlotId?,
	pickerItems: { EquippableItemViewModel.TEquippableItemViewData },
}

return {}
