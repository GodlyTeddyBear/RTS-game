--!strict

--[[
	ItemConfig — Static definitions for all items.

	Add entries in the slice that matches the item's category (Materials, Weapons,
	Armor, Accessories, Consumables, Cosmetics).
]]

local ItemData = require(script.Parent.Parent.Types.ItemData)

local config = {}

for _, mod in
	{
		require(script.Materials),
		require(script.Weapons),
		require(script.Armor),
		require(script.Accessories),
		require(script.Consumables),
		require(script.Cosmetics),
	}
do
	for k, v in mod do
		config[k] = v
	end
end

return table.freeze(config) :: { [string]: ItemData.ItemData }
