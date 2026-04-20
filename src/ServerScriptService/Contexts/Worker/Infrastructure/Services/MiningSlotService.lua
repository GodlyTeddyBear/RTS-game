--!strict

--[[
	Mining Slot Service - Infrastructure Service

	Delegates all slot logic to BaseSlotService. Only responsibility is resolving
	the MiningSlotCalculator from the registry on Init.

	Slot map structure:
	  self.SlotMap[userId][oreId][slotIndex] = workerId
]]

local BaseSlotService = require(script.Parent.BaseSlotService)

local MiningSlotService = setmetatable({}, { __index = BaseSlotService })
MiningSlotService.__index = MiningSlotService

export type TMiningSlotService = BaseSlotService.TBaseSlotService

function MiningSlotService.new(): TMiningSlotService
	local self = BaseSlotService.new()
	return setmetatable(self, MiningSlotService)
end

function MiningSlotService:Init(registry: any, _name: string)
	self.SlotCalculator = registry:Get("MiningSlotCalculator")
end

return MiningSlotService
