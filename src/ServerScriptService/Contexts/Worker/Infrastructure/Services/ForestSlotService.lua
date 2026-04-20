--!strict

--[[
	Forest Slot Service - Infrastructure Service

	Delegates all slot logic to BaseSlotService. Only responsibility is resolving
	the ForestSlotCalculator from the registry on Init.

	Slot map structure:
	  self.SlotMap[userId][treeId][slotIndex] = workerId
]]

local BaseSlotService = require(script.Parent.BaseSlotService)

local ForestSlotService = setmetatable({}, { __index = BaseSlotService })
ForestSlotService.__index = ForestSlotService

export type TForestSlotService = BaseSlotService.TBaseSlotService

function ForestSlotService.new(): TForestSlotService
	local self = BaseSlotService.new()
	return setmetatable(self, ForestSlotService)
end

function ForestSlotService:Init(registry: any, _name: string)
	self.SlotCalculator = registry:Get("ForestSlotCalculator")
end

return ForestSlotService
