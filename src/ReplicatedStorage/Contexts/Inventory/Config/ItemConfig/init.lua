--!strict

local ItemData = require(script.Parent.Parent.Types.ItemData)
local Equipment = require(script.Equipment)
local Materials = require(script.Materials)

local ItemConfig: { [string]: ItemData.ItemData } = table.clone(Materials)

for itemId, itemData in Equipment do
	ItemConfig[itemId] = itemData
end

return table.freeze(ItemConfig)
