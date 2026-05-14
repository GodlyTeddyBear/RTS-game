--!strict

local EquipmentTypes = require(script.Parent.Parent.Types.EquipmentTypes)

type TEquipmentDefinition = EquipmentTypes.TEquipmentDefinition

local Slots = table.freeze({
	Weapon = {
		Id = "Weapon",
		AssetFamily = "Tool",
	},
	Armor = {
		Id = "Armor",
		AssetFamily = "Armor",
	},
	Accessory = {
		Id = "Accessory",
		AssetFamily = "Accessory",
	},
})

local Definitions: { [string]: TEquipmentDefinition } = {
	DefaultTool = {
		ItemId = "DefaultTool",
		SlotId = "Weapon",
		AssetFamily = "Tool",
		AssetId = "Default",
	},
	DefaultArmor = {
		ItemId = "DefaultArmor",
		SlotId = "Armor",
		AssetFamily = "Armor",
		AssetId = "Default",
	},
	DefaultAccessory = {
		ItemId = "DefaultAccessory",
		SlotId = "Accessory",
		AssetFamily = "Accessory",
		AssetId = "Default",
	},
}

return table.freeze({
	Slots = Slots,
	Definitions = table.freeze(Definitions),
})
