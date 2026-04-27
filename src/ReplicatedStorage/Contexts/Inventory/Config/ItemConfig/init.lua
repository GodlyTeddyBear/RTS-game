--!strict

local ItemData = require(script.Parent.Parent.Types.ItemData)
local Materials = require(script.Materials)

local ItemConfig: { [string]: ItemData.ItemData } = table.clone(Materials)

return table.freeze(ItemConfig)
