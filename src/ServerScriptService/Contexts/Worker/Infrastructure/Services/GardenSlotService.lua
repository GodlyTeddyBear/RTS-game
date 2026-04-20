--!strict

--[[
	Garden Slot Service - Infrastructure Service

	Delegates all slot logic to BaseSlotService. Only responsibility is resolving
	the GardenSlotCalculator from the registry on Init.

	Slot map structure:
	  self.SlotMap[userId][plantId][slotIndex] = workerId
]]

local BaseSlotService = require(script.Parent.BaseSlotService)

local GardenSlotService = setmetatable({}, { __index = BaseSlotService })
GardenSlotService.__index = GardenSlotService

export type TGardenSlotService = BaseSlotService.TBaseSlotService

function GardenSlotService.new(): TGardenSlotService
	local self = BaseSlotService.new()
	return setmetatable(self, GardenSlotService)
end

function GardenSlotService:Init(registry: any, _name: string)
	self.SlotCalculator = registry:Get("GardenSlotCalculator")
end

return GardenSlotService
