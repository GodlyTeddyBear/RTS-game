--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local useMemo = React.useMemo
local useState = React.useState

local EquippableItemViewModel = require(script.Parent.Parent.ViewModels.EquippableItemViewModel)
local EquipmentUiTypes = require(script.Parent.Parent.Parent.Types.EquipmentUiTypes)

type TEquipUiSlotId = EquipmentUiTypes.TEquipUiSlotId

type TGuildActions = {
	equipItem: (adventurerId: string, slotType: string, inventorySlotIndex: number) -> (),
	unequipItem: (adventurerId: string, slotType: string) -> (),
}

type TUseAdventurerDetailScreenControllerParams = {
	adventurerId: string,
	inventoryState: any,
	guildActions: TGuildActions,
}

export type TAdventurerDetailScreenController = {
	selectedSlotId: TEquipUiSlotId?,
	pickerItems: { EquippableItemViewModel.TEquippableItemViewData },
	onSelectSlot: (slotId: TEquipUiSlotId, backendSlotType: string?, isFuture: boolean) -> (),
	onSelectPickerItem: (slotIndex: number) -> (),
	onUnequipSlot: (backendSlotType: string?) -> (),
}

local function useAdventurerDetailScreenController(
	params: TUseAdventurerDetailScreenControllerParams
): TAdventurerDetailScreenController
	local selectedSlotId, setSelectedSlotId = useState("Weapon" :: TEquipUiSlotId?)
	local selectedBackendSlotType, setSelectedBackendSlotType = useState("Weapon" :: string?)

	local pickerItems = useMemo(function()
		if selectedBackendSlotType == nil then
			return {}
		end

		return EquippableItemViewModel.buildList(params.inventoryState, selectedBackendSlotType)
	end, { params.inventoryState, selectedBackendSlotType } :: { any })

	local onSelectSlot = useMemo(function()
		return function(slotId: TEquipUiSlotId, backendSlotType: string?, isFuture: boolean)
			if isFuture or backendSlotType == nil then
				return
			end
			setSelectedSlotId(slotId)
			setSelectedBackendSlotType(backendSlotType)
		end
	end, {})

	local onSelectPickerItem = useMemo(function()
		return function(slotIndex: number)
			if selectedBackendSlotType == nil then
				return
			end
			params.guildActions.equipItem(params.adventurerId, selectedBackendSlotType, slotIndex)
		end
	end, { params.adventurerId, params.guildActions, selectedBackendSlotType } :: { any })

	local onUnequipSlot = useMemo(function()
		return function(backendSlotType: string?)
			if backendSlotType == nil then
				return
			end
			params.guildActions.unequipItem(params.adventurerId, backendSlotType)
		end
	end, { params.adventurerId, params.guildActions } :: { any })

	return {
		selectedSlotId = selectedSlotId,
		pickerItems = pickerItems,
		onSelectSlot = onSelectSlot,
		onSelectPickerItem = onSelectPickerItem,
		onUnequipSlot = onUnequipSlot,
	}
end

return useAdventurerDetailScreenController
