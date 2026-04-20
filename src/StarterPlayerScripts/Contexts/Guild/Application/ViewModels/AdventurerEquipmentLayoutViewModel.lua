--!strict

local EquipmentUiTypes = require(script.Parent.Parent.Parent.Types.EquipmentUiTypes)
local AdventurerViewModel = require(script.Parent.AdventurerViewModel)

type TEquipUiSlotId = EquipmentUiTypes.TEquipUiSlotId
type TBuildLayoutParams = EquipmentUiTypes.TBuildLayoutParams
type TAdventurerEquipmentLayoutViewModel = EquipmentUiTypes.TAdventurerEquipmentLayoutViewModel

type TSlotDescriptor = {
	SlotId: TEquipUiSlotId,
	Label: string,
	BackendSlotType: string?,
	IsFuture: boolean,
	EquipmentResolver: (AdventurerViewModel.TAdventurerViewModel) -> AdventurerViewModel.TEquipmentSlotViewModel?,
}

local SLOT_DESCRIPTORS: { TSlotDescriptor } = {
	{
		SlotId = "Weapon",
		Label = "Weapon",
		BackendSlotType = "Weapon",
		IsFuture = false,
		EquipmentResolver = function(vm)
			return vm.WeaponSlot
		end,
	},
	{
		SlotId = "Helmet",
		Label = "Helmet",
		BackendSlotType = nil,
		IsFuture = true,
		EquipmentResolver = function()
			return nil
		end,
	},
	{
		SlotId = "Torso",
		Label = "Torso",
		BackendSlotType = "Armor",
		IsFuture = false,
		EquipmentResolver = function(vm)
			return vm.ArmorSlot
		end,
	},
	{
		SlotId = "Legs",
		Label = "Legs",
		BackendSlotType = nil,
		IsFuture = true,
		EquipmentResolver = function()
			return nil
		end,
	},
	{
		SlotId = "Accessory1",
		Label = "Accessory1",
		BackendSlotType = "Accessory",
		IsFuture = false,
		EquipmentResolver = function(vm)
			return vm.AccessorySlot
		end,
	},
	{
		SlotId = "Accessory2",
		Label = "Accessory2",
		BackendSlotType = nil,
		IsFuture = true,
		EquipmentResolver = function()
			return nil
		end,
	},
	{
		SlotId = "Accessory3",
		Label = "Accessory3",
		BackendSlotType = nil,
		IsFuture = true,
		EquipmentResolver = function()
			return nil
		end,
	},
	{
		SlotId = "Accessory4",
		Label = "Accessory4",
		BackendSlotType = nil,
		IsFuture = true,
		EquipmentResolver = function()
			return nil
		end,
	},
}

local AdventurerEquipmentLayoutViewModel = {}

function AdventurerEquipmentLayoutViewModel.build(params: TBuildLayoutParams): TAdventurerEquipmentLayoutViewModel
	local slotTiles = {}
	local selectedSlotLabel = "Equipment"

	for _, descriptor in ipairs(SLOT_DESCRIPTORS) do
		local isSelected = params.selectedSlotId == descriptor.SlotId
		if isSelected then
			selectedSlotLabel = descriptor.Label
		end

		table.insert(slotTiles, table.freeze({
			SlotId = descriptor.SlotId,
			Label = descriptor.Label,
			BackendSlotType = descriptor.BackendSlotType,
			IsFuture = descriptor.IsFuture,
			IsSelected = isSelected,
			Equipment = descriptor.EquipmentResolver(params.adventurerViewModel),
		}))
	end

	local itemTiles = {}
	for _, item in ipairs(params.pickerItems) do
		table.insert(itemTiles, table.freeze({
			SlotIndex = item.SlotIndex,
			Name = item.Name,
			StatsText = item.StatsText,
			Quantity = item.Quantity,
		}))
	end

	local statRows = {
		table.freeze({ Label = "HP", Value = tostring(params.adventurerViewModel.EffectiveHP) }),
		table.freeze({ Label = "ATK", Value = tostring(params.adventurerViewModel.EffectiveATK) }),
		table.freeze({ Label = "DEF", Value = tostring(params.adventurerViewModel.EffectiveDEF) }),
	}

	return table.freeze({
		SlotTiles = slotTiles,
		ItemTiles = itemTiles,
		StatRows = statRows,
		SelectedSlotId = params.selectedSlotId,
		SelectedSlotLabel = selectedSlotLabel,
	})
end

return AdventurerEquipmentLayoutViewModel
