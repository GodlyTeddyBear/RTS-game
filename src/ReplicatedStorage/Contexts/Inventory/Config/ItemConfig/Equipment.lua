--!strict

local Category = require(script.Parent.Parent.Parent.Types.Category)
local ItemData = require(script.Parent.Parent.Parent.Types.ItemData)
local Rarity = require(script.Parent.Parent.Parent.Types.Rarity)

local EquipmentItems: { [string]: ItemData.ItemData } = {
	DefaultTool = {
		Id = "DefaultTool",
		Name = "Default Tool",
		Description = "A default tool equipment item used by the equipment runtime.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Common,
		Category = Category.Tool,
		Stackable = false,
		MaxStack = 1,
	},
	DefaultArmor = {
		Id = "DefaultArmor",
		Name = "Default Armor",
		Description = "A default armor equipment item used by the equipment runtime.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Common,
		Category = Category.Armor,
		Stackable = false,
		MaxStack = 1,
	},
	DefaultAccessory = {
		Id = "DefaultAccessory",
		Name = "Default Accessory",
		Description = "A default accessory equipment item used by the equipment runtime.",
		Icon = "rbxassetid://0",
		Rarity = Rarity.Common,
		Category = Category.Accessory,
		Stackable = false,
		MaxStack = 1,
	},
}

return table.freeze(EquipmentItems)
